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
                  :state      => :live,
                  :plan_name  => 'awesome')

    assert_equal '8010',    @storage.get('contract/service_id:2001/user_key:foo/id')
    assert_equal 'live',    @storage.get('contract/service_id:2001/user_key:foo/state')
    assert_equal 'awesome', @storage.get('contract/service_id:2001/user_key:foo/plan_name')
  end
  
  def test_save_without_required_attributes
    Contract.save(:service_id => '2001',
                  :user_key   => 'foo',
                  :id         => '8010',
                  :state      => :live)

    assert_equal '8010', @storage.get('contract/service_id:2001/user_key:foo/id')
    assert_equal 'live', @storage.get('contract/service_id:2001/user_key:foo/state')

    assert @storage.keys('contract/service_id:2001/user_key:foo/plan_name').empty?
  end

  def test_load
    @storage.set('contract/service_id:2001/user_key:foo/id', '8011')
    @storage.set('contract/service_id:2001/user_key:foo/state', 'suspended')
    @storage.set('contract/service_id:2001/user_key:foo/plan_name', 'crappy')
    contract = Contract.load(2001, 'foo')

    assert_equal '8011',     contract.id
    assert_equal :suspended, contract.state
    assert_equal 'crappy',   contract.plan_name
  end

  def test_load_without_required_attributes
    @storage.set('contract/service_id:2001/user_key:foo/id', '8011')
    @storage.set('contract/service_id:2001/user_key:foo/state', 'suspended')
    contract = Contract.load(2001, 'foo')

    assert_equal '8011',     contract.id
    assert_equal :suspended, contract.state
    assert_nil               contract.plan_name
  end
end
