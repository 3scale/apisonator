require File.dirname(__FILE__) + '/../test_helper'

class ContractTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @storage = ThreeScale::Backend.storage
    @storage.flushdb
  end

  def test_save
    Contract.save(:service_id => '2001',
                  :user_key   => 'foo',
                  :id         => '8010',
                  :state      => :live)

    assert_equal '8010', @storage.get('contract/id/service_id:2001/user_key:foo')
    assert_equal 'live', @storage.get('contract/state/service_id:2001/user_key:foo')
  end

  def test_load
    @storage.set('contract/id/service_id:2001/user_key:foo', '8011')
    @storage.set('contract/state/service_id:2001/user_key:foo', 'suspended')
    contract = Contract.load(2001, 'foo')

    assert_equal '8011', contract.id
    assert_equal :suspended, contract.state
  end

end
