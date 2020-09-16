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

    def test_master_metrics_not_defined_notifies_the_error_and_logs_it
      now = Time.now.utc
      invalid_metric = 'transactions/invalid_metric'

      Worker.logger.expects(:notify).with { |e| e.is_a?(MetricInvalid) }
      Worker.logger.expects(:error).with("NotifyJob metric \"#{invalid_metric}\" is invalid")

      Transactor::NotifyJob.perform(@provider_key, { invalid_metric => 1 }, now, now.to_f)
    end

    def test_timestamp_outside_defined_range_notifies_the_error_and_logs_it
      Worker.logger.expects(:notify).with { |e| e.is_a?(TransactionTimestampTooOld) }
      Worker.logger.expects(:error).with do |msg|
        msg.match?("NotifyJob #{@provider_key} #{@provider_application_id} "\
                   "reporting transactions older than "\
                   "#{Transaction.const_get(:REPORT_DEADLINE_PAST)} seconds is not allowed")
      end

      now = Time.now.utc
      job_timestamp = now - Transaction.const_get(:REPORT_DEADLINE_PAST) - 1

      Transactor::NotifyJob.perform(@provider_key,
                                    {'transactions/authorize' => 1},
                                    job_timestamp,
                                    job_timestamp.to_f)
    end
  end
end
