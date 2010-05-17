require File.dirname(__FILE__) + '/../../test_helper'

module Transactor
  class StatusTest < Test::Unit::TestCase
    include TestHelpers::EventMachine
    include TestHelpers::StorageKeys

    def setup
      @storage = ThreeScale::Backend.storage
      @storage.flushdb
    end

    def test_status_contains_usage_entries
      service_id  = 1001
      plan_id     = 2001
      contract_id = 3001
      metric_id   = 4001

      contract = Contract.new(:service_id => service_id,
                              :id         => contract_id,
                              :plan_id    => plan_id)
      Metric.save(:service_id => service_id, :id => metric_id, :name => 'foos')
      UsageLimit.save(:service_id => service_id,
                      :plan_id    => plan_id,
                      :metric_id  => metric_id,
                      :month      => 2000)

      time = Time.utc(2010, 5, 17, 12, 42)
      usage = {:month => {metric_id.to_s => 429}}

      Timecop.freeze(time) do
        status = Transactor::Status.new(contract, usage)

        assert_equal 1, status.usages.count

        usage = status.usages.first
        assert_equal :month,               usage.period
        assert_equal 'foos',               usage.metric_name
        assert_equal Time.utc(2010, 5, 1), usage.period_start
        assert_equal Time.utc(2010, 6, 1), usage.period_end
        assert_equal 2000,                 usage.max_value
        assert_equal 429,                  usage.current_value
      end
    end

    def test_xml_serialization
      service_id  = 1001
      plan_id     = 2001
      contract_id = 3001
      metric_id   = 4001

      contract = Contract.new(:service_id => service_id,
                              :id         => contract_id,
                              :plan_id    => plan_id,
                              :plan_name  => 'awesome')
      Metric.save(:service_id => service_id, :id => metric_id, :name => 'foos')
      UsageLimit.save(:service_id => service_id,
                      :plan_id    => plan_id,
                      :metric_id  => metric_id,
                      :month      => 2000)

      time = Time.utc(2010, 5, 17, 12, 42)
      usage = {:month => {metric_id.to_s => 429}}

      Timecop.freeze(time) do
        status = Transactor::Status.new(contract, usage)

        doc = Nokogiri::XML(status.to_xml)
        
        root = doc.at('status:root')        
        assert_not_nil doc.at('status:root')
        assert_equal 'awesome', root.at('plan').content

        usage = root.at('usage[metric = "foos"][period = "month"]')
        assert_not_nil usage
        assert_equal '2010-05-01 00:00:00', usage.at('period_start').content
        assert_equal '2010-06-01 00:00:00', usage.at('period_end').content
        assert_equal '429', usage.at('current_value').content
        assert_equal '2000', usage.at('max_value').content
      end
    end
  end
end
