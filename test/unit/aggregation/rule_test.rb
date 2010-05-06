require File.dirname(__FILE__) + '/../../test_helper'

class Aggregation::RuleTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @storage = ThreeScale::Backend.storage
    @storage.flushdb

    @service_id = 1
    @contract_id = 2
    @metric_id = 3
  end
  
  def test_increments_the_corresponding_stats_value
    rule = Aggregation::Rule.new(:service, :granularity => :day)
    time = Time.local(2010, 5, 6, 12, 30)
    transaction = build_transaction_at(time)
    key = storage_key(:day, time)

    @storage.set(key, 1024)

    assert_change :of => lambda { @storage.get(key) }, :from => '1024', :to => '1025' do
      rule.aggregate(transaction)
    end
  end

  def test_sets_expiration_time_for_volatile_keys
    rule = Aggregation::Rule.new(:service, :granularity => :day, :expires_in => 2 * 24 * 60 * 60)
    time = Time.now
    transaction = build_transaction_at(time)
    key = storage_key(:day, time)

    rule.aggregate(transaction)

    ttl = @storage.ttl(key)

    assert_not_equal -1, ttl
    assert_in_delta 2 * 24 * 60 * 60, ttl, 60
  end

  def test_does_not_update_set_of_services
    rule = Aggregation::Rule.new(:service, :granularity => :day)
    transaction = build_transaction_at(Time.now)

    assert_no_change :of => lambda { @storage.smembers('stats/services') } do
      rule.aggregate(transaction)
    end
  end

  def test_adds_the_contract_id_to_the_set_of_contract_ids_of_the_service
    rule = Aggregation::Rule.new(:service, :cinstance, :granularity => :day)
    transaction = build_transaction_at(Time.now)
    key = "stats/{service:#{@service_id}}/cinstances"

    assert_change :of => lambda { @storage.smembers(key) },
                  :from => nil, :to => [@contract_id.to_s] do
      rule.aggregate(transaction)
    end
  end

  private

  def storage_key(period, time)
    formatted_time = time.beginning_of_cycle(period).to_compact_s
    "stats/{service:#{@service_id}}/metric:#{@metric_id}/#{period}:#{formatted_time}"
  end

  def build_transaction_at(time)
    {:service    => @service_id,
     :cinstance  => @contract_id,
     :usage      => NumericHash.new(@metric_id => 1),
     :created_at => time}
  end
end
