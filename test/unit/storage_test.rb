require File.dirname(__FILE__) + '/../test_helper'

class StorageTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @storage = ThreeScale::Backend.storage
    @storage.flushdb
  end

  def test_basic_operations
    assert_nil @storage.get('foo')
    @storage.set('foo', 'bar')
    assert_equal 'bar', @storage.get('foo')
  end
end
