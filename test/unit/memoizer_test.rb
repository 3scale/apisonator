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
    Memoizer.reset!
    max_entries = Memoizer.const_get :MAX_ENTRIES
    max_entries.times do |i|
      Memoizer.memoize i.to_s, value
    end
    Memoizer.purge(Time.now.utc.to_i)
    assert_equal max_entries, Memoizer.stats[:size]
    Memoizer.memoize (max_entries+1).to_s, value
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

  # build_key.* returns an OPAQUE object. Should only test functionality.
  def test_memoizer_build_key
    with_a_class do |klass|
      key = Memoizer.build_key(klass, :some_method, :some, :args)
      assert !Memoizer.memoized?(key)
      klass.instance_eval do
        include Memoizer::Decorator
        def some_method(*args)
          :some_result
        end
        memoize :some_method
      end
      assert_equal :some_result, klass.some_method(:some, :args)
      assert Memoizer.memoized?(key)
      assert_equal :some_result, Memoizer.get(key)
    end
  end

  def test_memoized_build_keys_for_class
    methods_n_args = {
      some_method: [:some, :args],
      another_method: [:arg],
      yet_another: []
    }
    with_a_class do |klass|
      keys = Memoizer.build_keys_for_class(klass, methods_n_args)
      assert_equal 3, keys.size
      keys.each do |k|
        assert !Memoizer.memoized?(k)
      end
      klass.class_eval do
        include Memoizer::Decorator
        methods_n_args.keys.each do |m|
          define_singleton_method m do |*args|
            :some_result
          end
          memoize m
        end
      end
      methods_n_args.each_with_index do |(m, args), idx|
        assert_equal :some_result, klass.send(m, *args)
        assert Memoizer.memoized?(keys[idx])
        assert_equal :some_result, Memoizer.get(keys[idx])
      end
    end
  end

  def test_memoizer_decorator_instance_method
    with_a_class do |klass|
      assert_nothing_raised do
        klass.class_eval do
          include Memoizer::Decorator
          def foo(*args)
            :bar
          end
          memoize :foo
        end
      end
      obj = klass.new
      okey = Memoizer.build_key(obj, :foo)
      pokey = Memoizer.build_key(obj, :foo, 'some', 'params')
      assert !Memoizer.memoized?(okey)
      assert_equal :bar, obj.foo
      assert_equal :bar, Memoizer.get(okey)
      assert !Memoizer.memoized?(pokey)
      assert_equal :bar, obj.foo('some', 'params')
      assert_equal :bar, Memoizer.get(pokey)
    end
  end

  def test_memoizer_decorator_class_method_from_instance_eval
    with_a_class do |klass|
      assert_nothing_raised do
        klass.instance_eval do
          include Memoizer::Decorator
          def foo(*args)
            :bar
          end
          memoize :foo
        end
      end
      key = Memoizer.build_key(klass, :foo)
      pkey = Memoizer.build_key(klass, :foo, 'some', 'params')
      assert !Memoizer.memoized?(key)
      assert_equal :bar, klass.foo
      assert_equal :bar, Memoizer.get(key)
      assert !Memoizer.memoized?(pkey)
      assert_equal :bar, klass.foo('some', 'params')
      assert_equal :bar, Memoizer.get(pkey)
    end
  end

  def test_memoizer_decorator_class_method_from_metaclass
    with_a_class do |klass|
      assert_nothing_raised do
        klass.instance_eval do
          class << self
            include ThreeScale::Backend::Memoizer::Decorator
            def foo(*args)
              :bar
            end
            memoize :foo
          end
        end
      end
      key = Memoizer.build_key(klass, :foo)
      pkey = Memoizer.build_key(klass, :foo, 'some', 'params')
      assert !Memoizer.memoized?(key)
      assert_equal :bar, klass.foo
      assert_equal :bar, Memoizer.get(key)
      assert !Memoizer.memoized?(pkey)
      assert_equal :bar, klass.foo('some', 'params')
      assert_equal :bar, Memoizer.get(pkey)
    end
  end

  def test_memoizer_decorator_class_method_from_class_eval
    with_a_class do |klass|
      assert_nothing_raised do
        klass.class_eval do
          include Memoizer::Decorator
          def self.foo(*args)
            :bar
          end
          memoize :foo
        end
      end
      key = Memoizer.build_key(klass, :foo)
      pkey = Memoizer.build_key(klass, :foo, 'some', 'params')
      assert !Memoizer.memoized?(key)
      assert_equal :bar, klass.foo
      assert_equal :bar, Memoizer.get(key)
      assert !Memoizer.memoized?(pkey)
      assert_equal :bar, klass.foo('some', 'params')
      assert_equal :bar, Memoizer.get(pkey)
    end
  end

  def test_memoizer_decorator_decorates_class_instead_of_instance_method
    with_a_class do |klass|
      assert_nothing_raised do
        klass.class_eval do
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
      obj = klass.new
      okey = Memoizer.build_key(obj, :foo)
      key = Memoizer.build_key(klass, :foo)
      assert !Memoizer.memoized?(okey)
      assert !Memoizer.memoized?(key)
      assert_equal :instance, obj.foo
      assert_equal :class, klass.foo
      assert !Memoizer.memoized?(okey)
      assert Memoizer.memoized?(key)
    end
  end

  def test_memoizer_decorator_memoize_i_decorates_instance_instead_of_class_method
    with_a_class do |klass|
      assert_raise NameError do
        klass.class_eval do
          include Memoizer::Decorator
          def self.foo(*args)
            :class
          end
          memoize_i :foo
        end
      end
      assert_nothing_raised do
        klass.class_eval do
          def foo(*args)
            :instance
          end
          memoize_i :foo
        end
      end
      obj = klass.new
      okey = Memoizer.build_key(obj, :foo)
      key = Memoizer.build_key(klass, :foo)
      assert !Memoizer.memoized?(okey)
      assert !Memoizer.memoized?(key)
      assert_equal :instance, obj.foo
      assert_equal :class, klass.foo
      assert Memoizer.memoized?(okey)
      assert !Memoizer.memoized?(key)
    end
  end

  def test_memoizer_decorator_does_not_decorate_non_local_methods
    with_a_class do |klass|
      self.class.const_set(:MemoizerDecoratorTestModule, Module.new)
      MemoizerDecoratorTestModule.module_eval do
        def self.foo(*args)
          :class_from_module
        end
        def foo(*args)
          :instance_from_module
        end
      end
      [klass, klass.singleton_class].each do |k|
        k.include MemoizerDecoratorTestModule
        k.extend MemoizerDecoratorTestModule
        k.prepend MemoizerDecoratorTestModule
        # test that no module can interfere with memoize
        assert_raise NameError do
          k.class_eval do
            include Memoizer::Decorator
            memoize :foo
          end
        end
        assert_raise NameError do
          k.instance_eval do
            include Memoizer::Decorator
            memoize :foo
          end
        end
      end
      # add class and instance methods
      [klass, klass.singleton_class].each do |k|
        k.class_eval do
          def self.foo(*args)
            :class_from_parent
          end
          def foo(*args)
            :instance_from_parent
          end
        end
      end
      # test a derived class
      with_a_class klass do |child|
        [child, child.singleton_class].each do |k|
          assert_raise NameError do
            k.class_eval do
              include Memoizer::Decorator
              memoize :foo
            end
          end
          assert_raise NameError do
            k.instance_eval do
              include Memoizer::Decorator
              memoize :foo
            end
          end
        end
      end
      self.class.send :remove_const, :MemoizerDecoratorTestModule
    end
  end

  def test_memoizer_decorator_memoizes_class_method_without_binding
    with_a_class do |klass|
      mocked_method = Object.new
      { bind:  lambda { raise 'Error, bind called on memoized class method!' },
        owner: lambda { klass.singleton_class },
        name:  lambda { :foo },
        call:  lambda { :bar }
      }.each do |m, b|
        mocked_method.define_singleton_method(m) { b.call }
      end
      klass.define_singleton_method :method do |*args|
        mocked_method
      end
      assert_nothing_raised do
        klass.singleton_class.class_eval do
          include Memoizer::Decorator
          def foo
            :bar
          end
          memoize :foo
        end
      end
    end
  end
end

