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
end

