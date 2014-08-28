require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MemoizerTest < Test::Unit::TestCase
  def setup
    Memoizer.reset!
  end

  def key
    'simple_key'
  end

  def value
    'some_value'
  end

  def another_key
    'another_key'
  end

  def another_value
    'another_value'
  end

  def yet_another_key
    'yet_another_key'
  end

  def yet_another_value
    'yet_another_value'
  end

  def keys_values
    {
      key => value,
      another_key => another_value,
      yet_another_key => yet_another_value
    }
  end

  def test_memoizer_get
    Memoizer.clear key
    assert_nil Memoizer.get(key)
    Memoizer.memoize key, value
    assert_equal value, Memoizer.get(key)
    Memoizer.memoize key, nil
    assert_nil Memoizer.get(key)
  end

  def test_memoizer_block
    Memoizer.clear(key)
    assert_nil Memoizer.get(key)
    Memoizer.memoize_block(key) { value }
    assert_equal value, Memoizer.get(key)
  end

  def test_memoizer_clear
    keys_values.each do |k, v|
      Memoizer.memoize k, v
    end
    Memoizer.clear [key, another_key]
    assert !Memoizer.memoized?(key)
    assert_nil Memoizer.get(key)
    assert !Memoizer.memoized?(another_key)
    assert_nil Memoizer.get(another_key)
    assert Memoizer.memoized?(yet_another_key)
    assert_equal yet_another_value, Memoizer.get(yet_another_key)
  end

  def test_memoizer_memoize
    Memoizer.clear key
    Memoizer.memoize key, value
    assert_equal value, Memoizer.get(key)
  end

  def test_memoizer_memoized?
    Memoizer.clear [key, another_key]
    Memoizer.memoize key, value
    assert Memoizer.memoized?(key)
    assert !Memoizer.memoized?(another_key)
    expiretime = Memoizer.const_get :EXPIRE
    Memoizer.memoize another_key, another_value
    assert Memoizer.memoized?(another_key)
    Timecop.travel(Time.now + expiretime + 1) do
      assert !Memoizer.memoized?(another_key)
    end
  end

  def test_memoizer_reset!
    Memoizer.memoize key, value
    Memoizer.reset!
    assert !Memoizer.memoized?(key)
    Memoizer.memoize key, value
    Memoizer.memoize another_key, another_value
    5.times { Memoizer.memoized? key }
    3.times { Memoizer.memoized? another_key }
    7.times { Memoizer.memoized? yet_another_key }
    assert_not_equal 0, Memoizer.stats[:hits]
    assert_not_equal 0, Memoizer.stats[:count]
    assert_not_equal 0, Memoizer.stats[:size]
    Memoizer.reset!
    assert_equal 0, Memoizer.stats[:hits]
    assert_equal 0, Memoizer.stats[:count]
    assert_equal 0, Memoizer.stats[:size]
  end

  def test_memoizer_stats
    gets_per_key = { key => 3, another_key => 7, yet_another_key => 5 }
    memoized_keys = Hash[keys_values.to_a.sample(gets_per_key.size - 1)]
    Memoizer.reset!
    memoized_keys.each do |k, v|
      Memoizer.memoize k, v
    end
    gets_per_key.each do |k, g|
      g.times do
        Memoizer.memoized? k
      end
    end
    hits = memoized_keys.reduce(0) do |acc, (k, _)|
      acc + gets_per_key[k]
    end
    assert_equal hits, Memoizer.stats[:hits]
    count = gets_per_key.reduce(0) { |acc, (_, v)| acc + v }
    assert_equal count, Memoizer.stats[:count]
    assert_equal memoized_keys.size, Memoizer.stats[:size]
  end

  def test_memoizer_purge
    expiretime = Memoizer.const_get :EXPIRE
    Memoizer.reset!
    Memoizer.memoize key, value
    Memoizer.purge Time.now.utc.to_i + expiretime + 1
    assert !Memoizer.memoized?(key)
  end

  def test_memoizer_purge_max_entries
    max_entries = Memoizer.const_get :MAX_ENTRIES
    (max_entries+1).times do |i|
      Memoizer.memoize i.to_s, value
    end
    Memoizer.purge(Time.now.utc.to_i)
    assert_equal 0, Memoizer.stats[:size]
  end

  def with_a_class(parent = Object)
    # Test the decoration of methods
    # first create a class and give it a name to refer to
    # (we need to const_set it before using memoize, since otherwise
    # the class would have no name by the time memoize executes).
    mysym = (parent.to_s.split(':').last + "Child").to_sym
    self.class.send :remove_const, mysym rescue nil
    klass = self.class.const_set(mysym, Class.new(parent))
    yield klass
  ensure
    self.class.send :remove_const, mysym
  end

  def test_memoizer_build_key
    # it is probably debatable whether a key should have a specific type
    assert Memoizer.build_key(self, :some_method, :some, :args).kind_of?(String)
  end

  def test_memoized_build_keys_for_class
    keys = Memoizer.build_keys_for_class(self,
                                         some_method: [:some, :args],
                                         another_method: [:arg],
                                         yet_another: [])
    assert_equal 3, keys.size
    keys.each do |k|
      assert k.kind_of?(String)
    end
  end

  def test_memoizer_decorator_instance_method
    # Test the decoration of methods
    # first create a class and give it a name to refer to
    # (we need to const_set it before using memoize, since otherwise
    # the class would have no name by the time memoize executes).
    # and then declare :foo as memoized and run assertions.
    self.class.send :remove_const, :MemoizerDecoratorTest rescue nil
    self.class.const_set(:MemoizerDecoratorTest, Class.new)
    assert_nothing_raised do
      MemoizerDecoratorTest.class_eval do
        include Memoizer::Decorator
        def foo(*args)
          :bar
        end
        memoize :foo
      end
    end
    obj = MemoizerDecoratorTest.new
    okey = Memoizer.build_key(obj, :foo)
    pokey = Memoizer.build_key(obj, :foo, 'some', 'params')
    assert !Memoizer.memoized?(okey)
    assert_equal :bar, obj.foo
    assert_equal :bar, Memoizer.get(okey)
    assert !Memoizer.memoized?(pokey)
    assert_equal :bar, obj.foo('some', 'params')
    assert_equal :bar, Memoizer.get(pokey)
    self.class.send :remove_const, :MemoizerDecoratorTest
  end

  def test_memoizer_decorator_class_method_from_instance_eval
    self.class.send :remove_const, :MemoizerDecoratorTest rescue nil
    self.class.const_set(:MemoizerDecoratorTest, Class.new)
    assert_nothing_raised do
      MemoizerDecoratorTest.instance_eval do
        include Memoizer::Decorator
        def foo(*args)
          :bar
        end
        memoize :foo
      end
    end
    key = Memoizer.build_key(MemoizerDecoratorTest, :foo)
    pkey = Memoizer.build_key(MemoizerDecoratorTest, :foo, 'some', 'params')
    assert !Memoizer.memoized?(key)
    assert_equal :bar, MemoizerDecoratorTest.foo
    assert_equal :bar, Memoizer.get(key)
    assert !Memoizer.memoized?(pkey)
    assert_equal :bar, MemoizerDecoratorTest.foo('some', 'params')
    assert_equal :bar, Memoizer.get(pkey)
    self.class.send :remove_const, :MemoizerDecoratorTest
  end

  def test_memoizer_decorator_class_method_from_metaclass
    self.class.send :remove_const, :MemoizerDecoratorTest rescue nil
    self.class.const_set(:MemoizerDecoratorTest, Class.new)
    assert_nothing_raised do
      MemoizerDecoratorTest.instance_eval do
        class << self
          include ThreeScale::Backend::Memoizer::Decorator
          def foo(*args)
            :bar
          end
          memoize :foo
        end
      end
    end
    key = Memoizer.build_key(MemoizerDecoratorTest, :foo)
    pkey = Memoizer.build_key(MemoizerDecoratorTest, :foo, 'some', 'params')
    assert !Memoizer.memoized?(key)
    assert_equal :bar, MemoizerDecoratorTest.foo
    assert_equal :bar, Memoizer.get(key)
    assert !Memoizer.memoized?(pkey)
    assert_equal :bar, MemoizerDecoratorTest.foo('some', 'params')
    assert_equal :bar, Memoizer.get(pkey)
    self.class.send :remove_const, :MemoizerDecoratorTest
  end

  def test_memoizer_decorator_class_method_from_class_eval
    self.class.send :remove_const, :MemoizerDecoratorTest rescue nil
    self.class.const_set(:MemoizerDecoratorTest, Class.new)
    assert_nothing_raised do
      MemoizerDecoratorTest.class_eval do
        include Memoizer::Decorator
        def self.foo(*args)
          :bar
        end
        memoize :foo
      end
    end
    key = Memoizer.build_key(MemoizerDecoratorTest, :foo)
    pkey = Memoizer.build_key(MemoizerDecoratorTest, :foo, 'some', 'params')
    assert !Memoizer.memoized?(key)
    assert_equal :bar, MemoizerDecoratorTest.foo
    assert_equal :bar, Memoizer.get(key)
    assert !Memoizer.memoized?(pkey)
    assert_equal :bar, MemoizerDecoratorTest.foo('some', 'params')
    assert_equal :bar, Memoizer.get(pkey)
    self.class.send :remove_const, :MemoizerDecoratorTest
  end

  def test_memoizer_decorator_decorates_class_instead_of_instance_method
    self.class.send :remove_const, :MemoizerDecoratorTest rescue nil
    self.class.const_set(:MemoizerDecoratorTest, Class.new)
    assert_nothing_raised do
      MemoizerDecoratorTest.class_eval do
        include Memoizer::Decorator
        def self.foo(*args)
          :class
        end
        def foo(*args)
          :instance
        end
        memoize :foo
      end
    end
    obj = MemoizerDecoratorTest.new
    okey = Memoizer.build_key(obj, :foo)
    key = Memoizer.build_key(MemoizerDecoratorTest, :foo)
    assert !Memoizer.memoized?(okey)
    assert !Memoizer.memoized?(key)
    assert_equal :instance, obj.foo
    assert_equal :class, MemoizerDecoratorTest.foo
    assert !Memoizer.memoized?(okey)
    assert Memoizer.memoized?(key)
    self.class.send :remove_const, :MemoizerDecoratorTest
  end

  def test_memoizer_decorator_memoize_i_decorates_instance_instead_of_class_method
    self.class.send :remove_const, :MemoizerDecoratorTest rescue nil
    self.class.const_set(:MemoizerDecoratorTest, Class.new)
    assert_raise NameError do
      MemoizerDecoratorTest.class_eval do
        include Memoizer::Decorator
        def self.foo(*args)
          :class
        end
        memoize_i :foo
      end
    end
    assert_nothing_raised do
      MemoizerDecoratorTest.class_eval do
        def foo(*args)
          :instance
        end
        memoize_i :foo
      end
    end
    obj = MemoizerDecoratorTest.new
    okey = Memoizer.build_key(obj, :foo)
    key = Memoizer.build_key(MemoizerDecoratorTest, :foo)
    assert !Memoizer.memoized?(okey)
    assert !Memoizer.memoized?(key)
    assert_equal :instance, obj.foo
    assert_equal :class, MemoizerDecoratorTest.foo
    assert Memoizer.memoized?(okey)
    assert !Memoizer.memoized?(key)
    self.class.send :remove_const, :MemoizerDecoratorTest
  end

  def test_memoizer_decorator_does_not_decorate_non_local_methods
    self.class.send :remove_const, :MemoizerDecoratorTest rescue nil
    self.class.const_set(:MemoizerDecoratorTest, Class.new)
    self.class.const_set(:MemoizerDecoratorTestModule, Module.new)
    MemoizerDecoratorTestModule.module_eval do
      def self.foo(*args)
        :class_from_module
      end
      def foo(*args)
        :instance_from_module
      end
    end
    [MemoizerDecoratorTest, MemoizerDecoratorTest.singleton_class].each do |k|
      k.include MemoizerDecoratorTestModule
      k.extend MemoizerDecoratorTestModule
      k.prepend MemoizerDecoratorTestModule
      k.class_eval do
        def self.foo(*args)
          :class_from_parent
        end
        def foo(*args)
          :instance_from_parent
        end
      end
    end
    self.class.const_set(:MemoizerDecoratorTestChild, Class.new(MemoizerDecoratorTest))
    assert_raise NameError do
      MemoizerDecoratorTestChild.class_eval do
        include Memoizer::Decorator
        memoize :foo
      end
    end
    assert_raise NameError do
      MemoizerDecoratorTestChild.instance_eval do
        include Memoizer::Decorator
        memoize :foo
      end
    end
    self.class.send :remove_const, :MemoizerDecoratorTestModule
    self.class.send :remove_const, :MemoizerDecoratorTest
  end
end

