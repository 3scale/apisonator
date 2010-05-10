require File.dirname(__FILE__) + '/../test_helper'

class StorageKeyHelpersTest < Test::Unit::TestCase
  include StorageKeyHelpers

  def test_encode_key
    assert_equal "hello+world", encode_key('hello world')
  end
end
