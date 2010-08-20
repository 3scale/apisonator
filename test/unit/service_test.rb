require File.dirname(__FILE__) + '/../test_helper'

class ServiceTest < Test::Unit::TestCase
  def setup
    Storage.instance(true).flushdb
  end

  def test_load_id_bang_raises_an_exception_if_service_does_not_exist
    assert_raise ProviderKeyInvalid do
      Service.load_id!('foo')
    end
  end

  def test_load_id_bang_returns_service_id_if_it_exists
    Service.save(:provider_key => 'foo', :id => '1001')

    assert_equal '1001', Service.load_id!('foo')
  end
end
