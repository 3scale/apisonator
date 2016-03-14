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
      Transactor::ProcessJob.expects(:perform).
        with([{:service_id     => @master_service_id,
               :application_id => @provider_application_id,
               :timestamp      => Time.utc(2010, 7, 29, 18, 21),
               :usage          => {@master_hits_id => 1, @master_authorizes_id => 1}}], :master => true)

      Transactor::NotifyJob.perform(@provider_key,
                                    {'transactions/authorize' => 1},
                                    Time.utc(2010, 7, 29, 18, 21),
                                    Time.utc(2010, 7, 29, 18, 21).to_f)
    end

    def test_does_not_raise_an_exception_if_provider_key_is_invalid
      assert_nothing_raised do
        Transactor::NotifyJob.perform('foo',
                                      {'transactions/authorize' => 1},
                                      Time.utc(2010, 7, 29, 18, 21),
                                      Time.utc(2010, 7, 29, 18, 21).to_f)
      end
    end

    def test_does_not_report_error_if_provider_key_is_invalid
      ErrorStorage.expects(:store).never

      Transactor::NotifyJob.perform('foo',
                                    {'transactions/authorize' => 1},
                                    Time.utc(2010, 7, 29, 18, 21),
                                    Time.utc(2010, 7, 29, 18, 21).to_f)
    end

    def test_does_not_process_the_transactions_if_provider_key_is_invalid
      Transactor::ProcessJob.expects(:perform).never

      Transactor::NotifyJob.perform('foo',
                                    {'transactions/authorize' => 1},
                                    Time.utc(2010, 7, 29, 18, 21),
                                    Time.utc(2010, 7, 29, 18, 21).to_f)
    end

    def test_raises_an_exception_if_metrics_are_invalid
      assert_raises MetricInvalid do
        Transactor::NotifyJob.perform(@provider_key,
                                      {'transactions/mutilate' => 1},
                                      Time.utc(2010, 7, 29, 18, 21),
                                      Time.utc(2010, 7, 29, 18, 21).to_f)
      end
    end

    def test_does_not_process_the_transactions_if_metrics_are_invalid
      Transactor::ProcessJob.expects(:perform).never

      begin
        Transactor::NotifyJob.perform(@provider_key,
                                      {'transactions/murder' => 1},
                                      Time.utc(2010, 7, 29, 18, 21),
                                      Time.utc(2010, 7, 29, 18, 21).to_f)
      rescue MetricInvalid
        # ...
      end
    end

    def test_raises_if_master_service_id_is_invalid
      Transactor::NotifyJob.configuration.stubs(:master_service_id).returns(nil)

      assert_raises do
        Transactor::NotifyJob.perform(@provider_key,
                                      {'transactions/authorize' => 1},
                                      Time.utc(2010, 7, 29, 18, 21),
                                      Time.utc(2010, 7, 29, 18, 21).to_f)
      end
    end
  end
end
