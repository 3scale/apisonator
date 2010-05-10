require File.dirname(__FILE__) + '/../test_helper'

class ServiceTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @storage = ThreeScale::Backend.storage
    @storage.flushdb
  end

  def test_save
    service = Service.save(:provider_key => 'foo', :id => '7001')
    assert_equal '7001', @storage.get('service/id/provider_key:foo')
  end

  def test_load_id
    @storage.set('service/id/provider_key:foo', '7002')
    assert_equal '7002', Service.load_id('foo')
  end
end
