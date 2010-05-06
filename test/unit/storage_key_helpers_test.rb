require File.dirname(__FILE__) + '/../test_helper'

class StorageKeyHelpersTest < Test::Unit::TestCase
  include StorageKeyHelpers
  
  def test_key_for_with_symbol
    assert_equal "foo", key_for(:foo)
  end
  
  def test_key_for_with_number
    assert_equal "125", key_for(125)
  end
  
  def test_key_for_with_hash
    assert_equal "foo:bar", key_for(:foo => :bar)
  end

  def test_key_for_with_nil
    assert_equal "", key_for(nil)
  end

  def test_key_for_encodes_values
    assert_equal "hello+world", key_for('hello world')
  end

  def test_key_for_with_array
    assert_equal "foo/bar/baz/day:20091101",
                 key_for(:foo, :bar, :baz, :day => '20091101')
  end

  def test_key_for_applies_key_tag
    assert_equal "{service:42}", key_for(:service => 42)
  end
end
