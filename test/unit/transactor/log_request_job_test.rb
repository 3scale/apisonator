require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Transactor
  class LogRequestJobTest < Test::Unit::TestCase
    include TestHelpers::Sequences

    def setup
      Storage.instance(true).flushdb

      @service_id = next_id

      @metric_id = next_id
      Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')

      @metric_id2 = next_id
      Metric.save(:service_id => @service_id, :id => @metric_id2, :name => 'other')

      @plan_id = next_id

      @application_id = next_id
      Application.save(:id         => @application_id,
                       :service_id => @service_id,
                       :state      => :active,
                       :plan_id    => @plan_id)
    end

    test 'processes the transactions' do
      @log1 = {'code' => '200', 'request' => '/request?bla=bla&', 'response' => '<xml>response</xml>'}

      Transactor::LogRequestJob.expects(:perform).
        with([{:service_id     => @service_id,
               :application_id => @application_id,
               :timestamp      => nil,
               :usage          => {'hits' => 1, 'other' => 6},
               :log          => @log1,
               :user_id        => nil}])

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1, 'other' => 6}, 'log' => @log1}}, Time.now.getutc.to_f)

      Transactor::LogRequestJob.expects(:perform).
        with([{:service_id     => @service_id,
               :application_id => @application_id,
               :timestamp      => nil,
               :usage          => nil,
               :log            => @log1,
               :user_id        => '666'}])

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'log' => @log1, 'user_id' => '666'}}, Time.now.getutc.to_f)

    

    end

    test 'does not process any transaction if no log is defined' do 

      Transactor::LogRequestJob.expects(:perform).never

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}}}, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => nil}}, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => ""}}, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => "rubbish"}}, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => {}}}, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => []}}, Time.now.getutc.to_f)

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => {'code' => '200', 'response' => 'response_text'}}},  Time.now.getutc.to_f)

    end


    test 'does not raise exceptions on not properly build logs' do
      assert_nothing_raised do
        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}}}, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => nil}}, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => ""}}, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => "rubbish"}}, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => {}}}, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => []}}, Time.now.getutc.to_f)

        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}, 'log' => {'code' => '200', 'response' => 'response_text'}}}, Time.now.getutc.to_f)


      end
    end
 
    test 'test conversion of parameters' do

      Timecop.freeze(Time.utc(2010, 8, 19, 11, 43)) do 

        @log = {'code' => '200', 'request' => '/request?bla=bla&', 'response' => '<xml>response</xml>'}
        LogRequestStorage.expects(:store_all).with([
          {:service_id     => @service_id,
           :application_id => @application_id,
           :timestamp      => Time.utc(2010, 8, 19, 11, 43),
           :log            => @log,
           :usage          => "hits: 1, other: 6, ",
           :user_id        => nil}])
        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'usage' => {'hits' => 1, 'other' => 6}, 'log' => @log}}, Time.now.getutc.to_f)

        @log = {'code' => '200', 'request' => '/request?bla=bla&', 'response' => '<xml>response</xml>'}
        LogRequestStorage.expects(:store_all).with([
          {:service_id     => @service_id,
           :application_id => @application_id,
           :timestamp      => Time.utc(2010, 8, 19, 11, 43),
           :log            => @log,
           :usage          => "N/A",
           :user_id        => nil}])
        Transactor::ReportJob.perform(
          @service_id, {'0' => {'app_id' => @application_id, 'log' => @log}}, Time.now.getutc.to_f)


        @log = {'request' => '/request?bla=bla&'}
        LogRequestStorage.expects(:store_all).with([
          {:service_id     => @service_id,
           :application_id => @application_id,
           :timestamp      => Time.utc(2010, 8, 19, 11, 43),
           :log            => {'request' => '/request?bla=bla&', 'code' => 'N/A', 'response' => 'N/A'},
           :usage          => "N/A",
           :user_id        => nil}])
        Transactor::ReportJob.perform(
         @service_id, {'0' => {'app_id' => @application_id, 'log' => @log}}, Time.now.getutc.to_f)

      
      end

      @log = {'request' => '/request?bla=bla&'}
      LogRequestStorage.expects(:store_all).with([
        {:service_id     => @service_id,
         :application_id => @application_id,
         :timestamp      => Time.utc(2010, 1, 1, 11, 11),
         :log            => {'request' => '/request?bla=bla&', 'code' => 'N/A', 'response' => 'N/A'},
         :usage          => "N/A",
         :user_id        => nil}])
      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'timestamp' => '2010-01-01 11:11:00', 'log' => @log}}, Time.now.getutc.to_f)
   
      long_request = (0...LogRequestStorage::ENTRY_MAX_LEN_REQUEST+100).map{ ('a'..'z').to_a[rand(26)] }.join
      long_response = (0...LogRequestStorage::ENTRY_MAX_LEN_RESPONSE+100).map{ ('a'..'z').to_a[rand(26)] }.join
      long_code = (0...LogRequestStorage::ENTRY_MAX_LEN_CODE+100).map{ ('a'..'z').to_a[rand(26)] }.join

      @log = {'request' => long_request, 'code' => long_code, 'response' => long_response}
      LogRequestStorage.expects(:store_all).with([
        {:service_id     => @service_id,
         :application_id => @application_id,
         :timestamp      => Time.utc(2010, 1, 1, 11, 11),
         :log            => {'request' => "#{long_request[0..LogRequestStorage::ENTRY_MAX_LEN_REQUEST]}#{LogRequestStorage::TRUNCATED}", 'code' => "#{long_code[0..LogRequestStorage::ENTRY_MAX_LEN_CODE]}#{LogRequestStorage::TRUNCATED}", 'response' => "#{long_response[0..LogRequestStorage::ENTRY_MAX_LEN_RESPONSE]}#{LogRequestStorage::TRUNCATED}"},
         :usage          => "N/A",
         :user_id        => nil}])

      Transactor::ReportJob.perform(
        @service_id, {'0' => {'app_id' => @application_id, 'timestamp' => '2010-01-01 11:11:00', 'log' => @log}}, Time.now.getutc.to_f)
   
    end
  end
end
