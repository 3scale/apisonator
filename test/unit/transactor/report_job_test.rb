require File.dirname(__FILE__) + '/../../test_helper'

module Transactor
  class ReportJobTest < Test::Unit::TestCase
    include TestHelpers::Sequences

    def setup
      Storage.instance(true).flushdb

      @service_id = next_id

      @metric_id = next_id
      Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')

      @plan_id = next_id
    
      @contract_id = next_id
      @user_key = 'user_key1'
      Contract.save(:id => @contract_id,
                    :service_id => @service_id,
                    :user_key => @user_key,
                    :state => :live,
                    :plan_id => @plan_id)
    end
    
    def test_processes_the_transactions
      Transactor::ProcessJob.expects(:perform).
        with([{:service_id  => @service_id,
               :contract_id => @contract_id,
               :timestamp   => nil,
               :usage       => {@metric_id => 1}}])

      Transactor::ReportJob.perform(
        @service_id, '0' => {'user_key' => @user_key, 'usage' => {'hits' => 1}})
    end

    def test_does_not_process_any_transaction_if_at_least_one_has_invalid_user_key
      Transactor::ProcessJob.expects(:perform).never

      Transactor::ReportJob.perform(
        @service_id, '0' => {'user_key' => @user_key, 'usage' => {'hits' => 1}},
                     '1' => {'user_key' => 'foo',     'usage' => {'hits' => 1}})
    end
    
    def test_does_not_process_any_transaction_if_at_least_one_has_invalid_metric
      Transactor::ProcessJob.expects(:perform).never
      
      Transactor::ReportJob.perform(
        @service_id, '0' => {'user_key' => @user_key, 'usage' => {'hits' => 1}},
                     '1' => {'user_key' => @user_key, 'usage' => {'foos' => 1}})
    end
    
    def test_does_not_process_any_transaction_if_at_least_one_has_invalid_usage_value
      Transactor::ProcessJob.expects(:perform).never
      
      Transactor::ReportJob.perform(
        @service_id, '0' => {'user_key' => @user_key, 'usage' => {'hits' => 1}},
                     '1' => {'user_key' => @user_key, 'usage' => {'hits' => 'a lot!'}})
    end
    
    def test_does_not_raise_an_exception_on_invalid_user_key
      assert_nothing_raised do
        Transactor::ReportJob.perform(
          @service_id, '0' => {'user_key' => 'foo', 'usage' => {'hits' => 1}})
      end
    end
    
    def test_does_not_raise_an_exception_on_invalid_metric
      assert_nothing_raised do
        Transactor::ReportJob.perform(
          @service_id, '0' => {'user_key' => @user_key, 'usage' => {'foos' => 1}})
      end
    end
    
    def test_does_not_raise_an_exception_on_invalid_usage_value
      assert_nothing_raised do
        Transactor::ReportJob.perform(
          @service_id, '0' => {'user_key' => @user_key, 'usage' => {'hits' => 'a lot!'}})
      end
    end

    def test_reports_error_on_invalid_user_key
      ErrorReporter.expects(:push).with(@service_id, is_a(UserKeyInvalid))

      Transactor::ReportJob.perform(
        @service_id, '0' => {'user_key' => 'foo', 'usage' => {'hits' => 1}})
    end
    
    def test_reports_error_on_invalid_metric
      ErrorReporter.expects(:push).with(@service_id, is_a(MetricInvalid))

      Transactor::ReportJob.perform(
        @service_id, '0' => {'user_key' => @user_key, 'usage' => {'foos' => 1}})
    end
    
    def test_reports_error_on_invalid_usage_value
      ErrorReporter.expects(:push).with(@service_id, is_a(UsageValueInvalid))

      Transactor::ReportJob.perform(
        @service_id, '0' => {'user_key' => @user_key, 'usage' => {'hits' => 'a lot!'}})
    end
  end
end
