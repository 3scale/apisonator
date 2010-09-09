require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Transactor
  class ProcessJobTest < Test::Unit::TestCase
    include TestHelpers::Sequences

    def setup
      @service_id = next_id
      @application_id_one = next_id
      @application_id_two = next_id

      @metric_id = next_id
    end

    def test_aggregates
      Aggregator.expects(:aggregate_all).
        with([{:service_id     => @service_id,
               :application_id => @application_id_one,
               :timestamp      => Time.utc(2010, 7, 26, 12, 5),
               :usage          => {@metric_id => 1}},
              {:service_id     => @service_id,
               :application_id => @application_id_two,
               :timestamp      => Time.utc(2010, 7, 26, 12, 5),
               :usage          => {@metric_id => 1}}])
    
      Transactor::ProcessJob.perform([{'service_id'     => @service_id,
                                       'application_id' => @application_id_one,
                                       'timestamp'      => '2010-07-26 12:05:00',
                                       'usage'          => {@metric_id => 1}},
                                      {'service_id'     => @service_id,
                                       'application_id' => @application_id_two,
                                       'timestamp'      => '2010-07-26 12:05:00',
                                       'usage'          => {@metric_id => 1}}])
    end
    
    def test_archives
      Archiver.expects(:add_all).
        with([{:service_id     => @service_id,
               :application_id => @application_id_one,
               :timestamp      => Time.utc(2010, 7, 26, 12, 12),
               :usage          => {@metric_id => 1}},
              {:service_id     => @service_id,
               :application_id => @application_id_two,
               :timestamp      => Time.utc(2010, 7, 26, 12, 12),
               :usage          => {@metric_id => 1}}])

      Transactor::ProcessJob.perform([{'service_id'     => @service_id,
                                       'application_id' => @application_id_one,
                                       'timestamp'      => '2010-07-26 12:12:00',
                                       'usage'          => {@metric_id => 1}},
                                      {'service_id'     => @service_id,
                                       'application_id' => @application_id_two,
                                       'timestamp'      => '2010-07-26 12:12:00',
                                       'usage'          => {@metric_id => 1}}])
    end

    def test_stores
      TransactionStorage.expects(:store_all).
        with([{:service_id     => @service_id,
               :application_id => @application_id_one,
               :timestamp      => Time.utc(2010, 9, 10, 16, 49),
               :usage          => {@metric_id => 1}}])

      Transactor::ProcessJob.perform([{'service_id'     => @service_id,
                                       'application_id' => @application_id_one,
                                       'timestamp'      => '2010-09-10 16:49:00',
                                       'usage'          => {@metric_id => 1}}])
    end
    
    def test_handles_transactions_with_utc_timestamps
      Aggregator.expects(:aggregate_all).with do |transactions|
        transactions.first[:timestamp] == Time.utc(2010, 5, 7, 18, 11, 25)
      end

      Transactor::ProcessJob.perform([{'service_id'     => @service_id,
                                       'application_id' => @application_id_one,
                                       'timestamp'   => '2010-05-07 18:11:25',
                                       'usage'       => {@metric_id => 1}}])
    end

    def test_handles_transactions_with_local_timestamps
      Aggregator.expects(:aggregate_all).with do |transactions|
        transactions.first[:timestamp] == Time.utc(2010, 5, 7, 11, 11, 25)
      end
      
      Transactor::ProcessJob.perform([{'service_id'     => @service_id,
                                       'application_id' => @application_id_one,
                                       'timestamp'      => '2010-05-07 18:11:25 +07:00',
                                       'usage'          => {@metric_id => 1}}])
    end

    def test_handles_transactions_with_blank_timestamps
      Timecop.freeze(Time.utc(2010, 8, 19, 11, 43)) do
        Aggregator.expects(:aggregate_all).with do |transactions|
          transactions.first[:timestamp] == Time.utc(2010, 8, 19, 11, 43)
        end
        
        Transactor::ProcessJob.perform([{'service_id'     => @service_id,
                                         'application_id' => @application_id_one,
                                         'timestamp'      => '',
                                         'usage'          => {@metric_id => 1}}])
      end
    end
  end
end
