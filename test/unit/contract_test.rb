require File.dirname(__FILE__) + '/../test_helper'

class ContractTest < Test::Unit::TestCase
  include TestHelpers::EventMachine
  include TestHelpers::StorageKeys

  def setup
    @storage = ThreeScale::Backend.storage
    @storage.flushdb
  end

  def test_save
    Contract.save(:service_id => '2001',
                  :user_key   => 'foo',
                  :id         => '8010',
                  :state      => :live,
                  :plan_id    => '3001',
                  :plan_name  => 'awesome')

    assert_equal '8010',    @storage.get('contract/service_id:2001/user_key:foo/id')
    assert_equal 'live',    @storage.get('contract/service_id:2001/user_key:foo/state')
    assert_equal '3001',    @storage.get('contract/service_id:2001/user_key:foo/plan_id')
    assert_equal 'awesome', @storage.get('contract/service_id:2001/user_key:foo/plan_name')
  end

  def test_load
    @storage.set('contract/service_id:2001/user_key:foo/id', '8011')
    @storage.set('contract/service_id:2001/user_key:foo/state', 'suspended')
    @storage.set('contract/service_id:2001/user_key:foo/plan_id', '3066')
    @storage.set('contract/service_id:2001/user_key:foo/plan_name', 'crappy')
    contract = Contract.load(2001, 'foo')

    assert_equal '8011',     contract.id
    assert_equal :suspended, contract.state
    assert_equal '3066',     contract.plan_id
    assert_equal 'crappy',   contract.plan_name
  end

  def test_current_values_returns_usage_values_for_the_current_periods
    service_id  = 1001
    plan_id     = 2001
    contract_id = 3001
    metric_id   = 4001

    Metric.save(:service_id => service_id,
                :id         => metric_id,
                :name       => 'hits')
    
    contract = Contract.new(:service_id => service_id,
                            :user_key   => 'foo',
                            :id         => contract_id,
                            :state      => :live,
                            :plan_id    => plan_id)
    contract.save

    usage_limit = UsageLimit.save(:service_id => service_id,
                                  :plan_id    => plan_id,
                                  :metric_id  => metric_id,
                                  :month      => 1000,
                                  :day        => 500)

    @storage.set(contract_key(service_id, contract_id, metric_id, :month, '20100501'), 256)
    @storage.set(contract_key(service_id, contract_id, metric_id, :day, '20100517'), 489)

    Timecop.freeze(Time.utc(2010, 5, 17, 11, 39)) do
      values = contract.current_values

      assert_equal 2,   values.size
      
      assert_not_nil    values[:month]
      assert_equal 256, values[:month][metric_id.to_s]
      
      assert_not_nil    values[:day]
      assert_equal 489, values[:day][metric_id.to_s]
    end
  end

  def test_current_values_is_empty_if_there_are_no_usage_limits
    service_id  = 1001
    plan_id     = 2001
    contract_id = 3001
    metric_id   = 4001

    Metric.save(:service_id => service_id,
                :id         => metric_id,
                :name       => 'hits')
    
    contract = Contract.new(:service_id => service_id,
                            :user_key   => 'foo',
                            :id         => contract_id,
                            :state      => :live,
                            :plan_id    => plan_id)
    contract.save

    @storage.set(contract_key(service_id, contract_id, metric_id, :month, '20100501'), 256)
    @storage.set(contract_key(service_id, contract_id, metric_id, :day, '20100517'), 489)

    Timecop.freeze(Time.utc(2010, 5, 17, 11, 39)) do
      assert contract.current_values.empty?, "Expected current_values to be empty"
    end
  end
end
