require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Transactor
  class NotifyJobTest < Test::Unit::TestCase
    include TestHelpers::Fixtures
    include TestHelpers::Sequences

    def setup
      Storage.instance(true).flushdb
      setup_provider_fixtures
    end

    def test_processes_the_transactions
      now = Time.now.utc

      Transactor::ProcessJob.expects(:perform).
        with([{:service_id     => @master_service_id,
               :application_id => @provider_application_id,
               :timestamp      => now,
               :usage          => {@master_hits_id => 1, @master_authorizes_id => 1}}])

      Transactor::NotifyJob.perform(@provider_key,
                                    {'transactions/authorize' => 1},
                                    now,
                                    now.to_f)
    end

    def test_does_not_raise_an_exception_if_provider_key_is_invalid
      now = Time.now.utc

      assert_nothing_raised do
        Transactor::NotifyJob.perform('foo',
                                      {'transactions/authorize' => 1},
                                      now,
                                      now.to_f)
      end
    end

    def test_does_not_report_error_if_provider_key_is_invalid
      now = Time.now.utc
      ErrorStorage.expects(:store).never

      Transactor::NotifyJob.perform('foo',
                                    {'transactions/authorize' => 1},
                                    now,
                                    now.to_f)
    end

    def test_does_not_process_the_transactions_if_provider_key_is_invalid
      now = Time.now.utc
      Transactor::ProcessJob.expects(:perform).never

      Transactor::NotifyJob.perform('foo',
                                    {'transactions/authorize' => 1},
                                    now,
                                    now.to_f)
    end

    def test_raises_an_exception_if_metrics_are_invalid
      now = Time.now.utc

      assert_raises MetricInvalid do
        Transactor::NotifyJob.perform(@provider_key,
                                      {'transactions/invalid_metric' => 1},
                                      now,
                                      now.to_f)
      end
    end

    def test_does_not_process_the_transactions_if_metrics_are_invalid
      now = Time.now.utc
      Transactor::ProcessJob.expects(:perform).never

      begin
        Transactor::NotifyJob.perform(@provider_key,
                                      {'transactions/invalid_metric' => 1},
                                      now,
                                      now.to_f)
      rescue MetricInvalid
        # ...
      end
    end
  end
end
