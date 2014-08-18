require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MemoizerTest < Test::Unit::TestCase
  def setup
    Memoizer.reset!
  end

  def test_memoizer_block_storage
    key = 'simple key'
    assert_nil Memoizer.get(key)

    Memoizer.memoize_block(key) { :foo }

    assert_equal :foo, Memoizer.get(key)
  end

  def test_memoizer_storage_clear
    Memoizer.memoize :foo, :bar
    assert_equal :bar, Memoizer.get(:foo)

    Memoizer.clear(:foo)
    assert !Memoizer.memoized?(:foo)
    assert_nil Memoizer.get(:foo)
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
    assert !Memoizer.memoized?("#{obj}.foo")
    assert_equal :bar, obj.foo
    assert_equal :bar, Memoizer.get("#{obj}.foo")
    assert !Memoizer.memoized?("#{obj}.foo-some-params")
    assert_equal :bar, obj.foo('some', 'params')
    assert_equal :bar, Memoizer.get("#{obj}.foo-some-params")
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
    assert !Memoizer.memoized?('MemoizerDecoratorTest.foo')
    assert_equal :bar, MemoizerDecoratorTest.foo
    assert_equal :bar, Memoizer.get("#{self.class}::MemoizerDecoratorTest.foo")
    assert !Memoizer.memoized?("#{self.class}::MemoizerDecoratorTest.foo-some-params")
    assert_equal :bar, MemoizerDecoratorTest.foo('some', 'params')
    assert_equal :bar, Memoizer.get("#{self.class}::MemoizerDecoratorTest.foo-some-params")
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
    assert !Memoizer.memoized?("#{self.class}::MemoizerDecoratorTest.foo")
    assert_equal :bar, MemoizerDecoratorTest.foo
    assert_equal :bar, Memoizer.get("#{self.class}::MemoizerDecoratorTest.foo")
    assert !Memoizer.memoized?("#{self.class}::MemoizerDecoratorTest.foo-some-params")
    assert_equal :bar, MemoizerDecoratorTest.foo('some', 'params')
    assert_equal :bar, Memoizer.get("#{self.class}::MemoizerDecoratorTest.foo-some-params")
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
    assert !Memoizer.memoized?("#{self.class}::MemoizerDecoratorTest.foo")
    assert_equal :bar, MemoizerDecoratorTest.foo
    assert_equal :bar, Memoizer.get("#{self.class}::MemoizerDecoratorTest.foo")
    assert !Memoizer.memoized?("#{self.class}::MemoizerDecoratorTest.foo-some-params")
    assert_equal :bar, MemoizerDecoratorTest.foo('some', 'params')
    assert_equal :bar, Memoizer.get("#{self.class}::MemoizerDecoratorTest.foo-some-params")
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
    assert !Memoizer.memoized?("#{obj}.foo")
    assert !Memoizer.memoized?("#{self.class}::MemoizerDecoratorTest.foo")
    assert_equal :instance, obj.foo
    assert_equal :class, MemoizerDecoratorTest.foo
    assert !Memoizer.memoized?("#{obj}.foo")
    assert Memoizer.memoized?("#{self.class}::MemoizerDecoratorTest.foo")
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
    assert !Memoizer.memoized?("#{obj}.foo")
    assert !Memoizer.memoized?("#{self.class}::MemoizerDecoratorTest.foo")
    assert_equal :instance, obj.foo
    assert_equal :class, MemoizerDecoratorTest.foo
    assert Memoizer.memoized?("#{obj}.foo")
    assert !Memoizer.memoized?("#{self.class}::MemoizerDecoratorTest.foo")
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

