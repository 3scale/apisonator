require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Transactor
  class ReportJobTest < Test::Unit::TestCase
    include TestHelpers::Sequences

    def setup
      Storage.instance(true).flushdb

      @service_id, @metric_id, @plan_id, @application_id = (1..4).map{ next_id }
      Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')
      Application.save(:id         => @application_id,
                       :service_id => @service_id,
                       :state      => :active,
                       :plan_id    => @plan_id)
      @context_info = {}
    end

    test 'processes the transactions' do
      Transactor::ProcessJob.expects(:perform).
        with([{:service_id     => @service_id,
               :application_id => @application_id,
               :timestamp      => nil,
               :usage          => {@metric_id => 1}}])

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}}}, Time.now.getutc.to_f, @context_info)
    end

    test 'does not process any transaction if at least one has invalid application id' do
      Transactor::ProcessJob.expects(:perform).never

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}},
                      '1' => {'app_id' => 'boo',           'usage' => {'hits' => 1}}},
                     Time.now.getutc.to_f,
                     @context_info)
    end

    test 'does not process any transaction if at least one has invalid metric' do
      Transactor::ProcessJob.expects(:perform).never

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}},
                      '1' => {'app_id' => @application_id, 'usage' => {'foos' => 1}}},
                     Time.now.getutc.to_f,
                     @context_info)
    end

    test 'does not process any transaction if at least one has invalid usage value' do
      Transactor::ProcessJob.expects(:perform).never

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}},
                      '1' => {'app_id' => @application_id, 'usage' => {'hits' => 'a lot!'}}},
                     Time.now.getutc.to_f,
                     @context_info)
    end

    test 'does not process any transaction if no usage is defined' do
      Transactor::ProcessJob.expects(:perform).never

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id},
                      '1' => {'app_id' => @application_id}},
                      Time.now.getutc.to_f,
                      @context_info)
    end

    test 'does not raise an exception on invalid application id' do
      assert_nothing_raised do
        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => 'boo', 'usage' => {'hits' => 1}}}, Time.now.getutc.to_f, @context_info)
      end
    end

    test 'does not raise an exception on invalid metric' do
      assert_nothing_raised do
        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'foos' => 1}}}, Time.now.getutc.to_f, @context_info)
      end
    end

    test 'does not raise an exception on invalid usage value' do
      assert_nothing_raised do
        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 'a lot!'}}}, Time.now.getutc.to_f, @context_info)
      end
    end

    test 'reports error on invalid application id' do
      ErrorStorage.expects(:store).with(@service_id, is_a(ApplicationNotFound), {})

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => 'boo', 'usage' => {'hits' => 1}}}, Time.now.getutc.to_f, @context_info)
    end

    test 'reports error on invalid metric' do
      ErrorStorage.expects(:store).with(@service_id, is_a(MetricInvalid), {})

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'foos' => 1}}}, Time.now.getutc.to_f, @context_info)
    end

    test 'reports error on invalid usage value' do
      ErrorStorage.expects(:store).with(@service_id, is_a(UsageValueInvalid), {})

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 'a lot!'}}}, Time.now.getutc.to_f, @context_info)
    end

    # Legacy authentication

    test 'processes the transaction with legacy user key' do
      user_key = 'foobar'
      Application.save_id_by_key(@service_id, user_key, @application_id)

      Transactor::ProcessJob.expects(:perform).
        with([{:service_id     => @service_id,
               :application_id => @application_id,
               :timestamp      => nil,
               :usage          => {@metric_id => 1}}])

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'user_key' => user_key, 'usage' => {'hits' => 1}}}, Time.now.getutc.to_f, @context_info)
    end


    test 'reports error on invalid legacy user key' do
      Application.save_id_by_key(@service_id, 'foobar', @application_id)

      ErrorStorage.expects(:store).with(@service_id, is_a(UserKeyInvalid), {})

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'user_key' => 'noway', 'usage' => {'hits' => 1}}}, Time.now.getutc.to_f, @context_info)
    end
  end
end
