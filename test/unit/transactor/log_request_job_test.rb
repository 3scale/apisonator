require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Transactor
  class LogRequestJobTest < Test::Unit::TestCase
    include TestHelpers::Sequences

    def setup
      Storage.instance(true).flushdb

      @service_id, @metric_id, @metric_id2, @plan_id, @application_id =
        (1..5).map{ next_id }
      Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')
      Metric.save(:service_id => @service_id, :id => @metric_id2, :name => 'other')
      Application.save(:id         => @application_id,
                       :service_id => @service_id,
                       :state      => :active,
                       :plan_id    => @plan_id)
      @context_info = {}
    end

    test 'does not process any transaction if no log is defined' do
      Transactor::LogRequestJob.expects(:perform).never

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}}}, @context_info, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => nil}}, @context_info, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => ""}}, @context_info, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => "rubbish"}}, @context_info, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => {}}}, @context_info, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => []}}, @context_info, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => {'code' => '200', 'response' => 'response_text'}}},  @context_info, Time.now.getutc.to_f)

    end

    test 'does not raise exceptions on not properly build logs' do
      assert_nothing_raised do
        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}}}, @context_info, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => nil}}, @context_info, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => ""}}, @context_info, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => "rubbish"}}, @context_info, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => {}}}, @context_info, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => []}}, @context_info, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => {'code' => '200', 'response' => 'response_text'}}}, @context_info, Time.now.getutc.to_f)
      end
    end

  end
end
