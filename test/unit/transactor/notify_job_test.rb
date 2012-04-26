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
      ErrorStorage.expects(:store).never

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

    def test_secondary_service
      @secondary_service_id = ThreeScale::Backend.configuration.secondary_service_id.to_s

      @secondary_hits_id         = next_id
      @secondary_reports_id      = next_id
      @secondary_authorizes_id   = next_id
      @secondary_transactions_id = next_id

      Metric.save(
        :service_id => @secondary_service_id, :id => @secondary_hits_id, :name => 'hits',
        :children => [
          Metric.new(:id => @secondary_reports_id,    :name => 'transactions/create_multiple'),
          Metric.new(:id => @secondary_authorizes_id, :name => 'transactions/authorize')])

      Metric.save(
        :service_id => @secondary_service_id, :id => @secondary_transactions_id,
        :name => 'transactions')

      @secondary_plan_id = next_id

      @provider_application_id = next_id
      @provider_key = "provider_key#{@provider_application_id}"

      Application.save(:service_id => @secondary_service_id,
                       :id         => @provider_application_id,
                       :state      => :active,
                       :plan_id    => @secondary_plan_id)

      Application.save_id_by_key(@secondary_service_id,
                                 @provider_key,
                                 @provider_application_id)

      @service_id = next_id
      @service = Core::Service.save!(:provider_key => @provider_key, :id => @service_id)

      @plan_id = next_id
      @plan_name = "plan#{@plan_id}"

      Transactor::ProcessJob.expects(:perform).
        with([{:service_id     => @secondary_service_id,
               :application_id => @provider_application_id,
               :timestamp      => Time.utc(2010, 7, 29, 18, 21),
               :usage          => {@secondary_hits_id => 1, @secondary_authorizes_id => 1}}], :master => true)

      Transactor::NotifyJob.perform(@provider_key,
                                    {'transactions/authorize' => 1},
                                    Time.utc(2010, 7, 29, 18, 21))
    end
  end
end
