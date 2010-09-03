require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Transactor
  class NotifyJobTest < Test::Unit::TestCase
    include TestHelpers::Sequences
    include TestHelpers::MasterService

    def setup
      Storage.instance(true).flushdb

      setup_master_service
      
      @provider_key = 'provider_key'
      @provider_application_id = next_id

      Application.save(:id         => @provider_application_id,
                       :service_id => @master_service_id,
                       :state      => :active,
                       :plan_id    => next_id)
      Application.save_id_by_key(@master_service_id, @provider_key, 
                                 @provider_application_id)
    end

    def test_processes_the_transactions
      Transactor::ProcessJob.expects(:perform).
        with([{:service_id     => @master_service_id,
               :application_id => @provider_application_id,
               :timestamp      => Time.utc(2010, 7, 29, 18, 21),
               :usage          => {@master_hits_id => 1, @master_authorizes_id => 1}}])

      Transactor::NotifyJob.perform(@provider_key, 
                                    {'transactions/authorize' => 1},
                                    Time.utc(2010, 7, 29, 18, 21))
    end

    def test_does_not_raise_an_exception_if_provider_key_is_invalid
      assert_nothing_raised do
        Transactor::NotifyJob.perform('foo',
                                      {'transactions/authorize' => 1},
                                      Time.utc(2010, 7, 29, 18, 21))
      end
    end

    def test_does_not_report_error_if_provider_key_is_invalid
      ErrorReporter.expects(:push).never

      Transactor::NotifyJob.perform('foo',
                                    {'transactions/authorize' => 1},
                                    Time.utc(2010, 7, 29, 18, 21))
    end

    def test_does_not_process_the_transactions_if_provider_key_is_invalid
      Transactor::ProcessJob.expects(:perform).never
      
      Transactor::NotifyJob.perform('foo',
                                    {'transactions/authorize' => 1},
                                    Time.utc(2010, 7, 29, 18, 21))
    end

    def test_raises_an_exception_if_metrics_are_invalid
      assert_raises MetricInvalid do
        Transactor::NotifyJob.perform(@provider_key,
                                      {'transactions/mutilate' => 1},
                                      Time.utc(2010, 7, 29, 18, 21))
      end
    end
    
    def test_does_not_process_the_transactions_if_metrics_are_invalid
      Transactor::ProcessJob.expects(:perform).never
      
      begin
        Transactor::NotifyJob.perform(@provider_key,
                                      {'transactions/murder' => 1},
                                      Time.utc(2010, 7, 29, 18, 21))
      rescue MetricInvalid
        # ...
      end
    end
  end
end
