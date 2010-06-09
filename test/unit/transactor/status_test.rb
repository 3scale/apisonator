require File.dirname(__FILE__) + '/../../test_helper'

module Transactor
  class StatusTest < Test::Unit::TestCase
    include TestHelpers::EventMachine
    include TestHelpers::StorageKeys

    def setup
      @storage = Storage.instance(true)
      @storage.flushdb
      
      @service_id  = 1001
      @plan_id     = 2001
      @contract_id = 3001
      @metric_id   = 4001

      @contract = Contract.new(:service_id => @service_id,
                               :id         => @contract_id,
                               :plan_id    => @plan_id)

      Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'foos')
    end

    def test_status_contains_usage_reports
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      time = Time.utc(2010, 5, 17, 12, 42)
      usage = {:month => {@metric_id.to_s => 429}}

      Timecop.freeze(time) do
        status = Transactor::Status.new(@contract, usage)

        assert_equal 1, status.usage_reports.count

        report = status.usage_reports.first
        assert_equal :month,               report.period
        assert_equal 'foos',               report.metric_name
        assert_equal Time.utc(2010, 5, 1), report.period_start
        assert_equal Time.utc(2010, 6, 1), report.period_end
        assert_equal 2000,                 report.max_value
        assert_equal 429,                  report.current_value
      end
    end

    def test_usage_report_is_marked_as_exceeded_when_current_value_is_greater_than_max_value
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      usage  = {:month => {@metric_id.to_s => 2002}}
      status = Transactor::Status.new(@contract, usage)

      assert status.usage_reports.first.exceeded?
    end
    
    def test_usage_report_is_not_marked_as_exceeded_when_current_value_is_less_than_max_value
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      usage  = {:month => {@metric_id.to_s => 1999}}
      status = Transactor::Status.new(@contract, usage)

      assert !status.usage_reports.first.exceeded?
    end
    
    def test_usage_report_is_not_marked_as_exceeded_when_current_value_equals_max_value
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      usage  = {:month => {@metric_id.to_s => 2000}}
      status = Transactor::Status.new(@contract, usage)

      assert !status.usage_reports.first.exceeded?
    end

    def test_status_is_authorized_by_default
      status = Transactor::Status.new(@contract, {})
      assert status.authorized?
    end

    def test_status_is_not_authorized_when_rejected
      status = Transactor::Status.new(@contract, {})
      status.reject!('user.inactive_contract')

      assert !status.authorized?
    end
    
    def test_status_contains_rejection_reason_when_rejected
      status = Transactor::Status.new(@contract, {})
      status.reject!('user.inactive_contract')

      assert_equal 'user.inactive_contract', status.rejection_reason_code
      assert_equal 'contract is not active', status.rejection_reason_text
    end

    def test_rejection_reason_can_be_set_only_once
      status = Transactor::Status.new(@contract, {})
      status.reject!('user.inactive_contract')
      status.reject!('user.exceeded_limits')
      
      assert_equal 'user.inactive_contract', status.rejection_reason_code
    end
  end
end
