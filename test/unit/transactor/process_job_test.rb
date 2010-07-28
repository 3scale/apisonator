require File.dirname(__FILE__) + '/../../test_helper'

module Transactor
  class ProcessJobTest < Test::Unit::TestCase
    include TestHelpers::Sequences

    def setup
      @service_id = next_id
      @contract_id_one = next_id
      @contract_id_two = next_id

      @metric_id = next_id
    end

    def test_aggregates
      Aggregator.expects(:aggregate).
        with([{:service_id  => @service_id,
               :contract_id => @contract_id_one,
               :timestamp   => Time.utc(2010, 7, 26, 12, 5),
               :usage       => {@metric_id => 1}},
              {:service_id  => @service_id,
               :contract_id => @contract_id_two,
               :timestamp   => Time.utc(2010, 7, 26, 12, 5),
               :usage       => {@metric_id => 1}}])
    
      Transactor::ProcessJob.perform([{'service_id'  => @service_id,
                                       'contract_id' => @contract_id_one,
                                       'timestamp'   => '2010-07-26 12:05:00',
                                       'usage'       => {@metric_id => 1}},
                                      {'service_id'  => @service_id,
                                       'contract_id' => @contract_id_two,
                                       'timestamp'   => '2010-07-26 12:05:00',
                                       'usage'       => {@metric_id => 1}}])
    end
    
    def test_archives
      Archiver.expects(:add).
        with([{:service_id  => @service_id,
               :contract_id => @contract_id_one,
               :timestamp   => Time.utc(2010, 7, 26, 12, 12),
               :usage       => {@metric_id => 1}},
              {:service_id  => @service_id,
               :contract_id => @contract_id_two,
               :timestamp   => Time.utc(2010, 7, 26, 12, 12),
               :usage       => {@metric_id => 1}}])

      Transactor::ProcessJob.perform([{'service_id'  => @service_id,
                                       'contract_id' => @contract_id_one,
                                       'timestamp'   => '2010-07-26 12:12:00',
                                       'usage'       => {@metric_id => 1}},
                                      {'service_id'  => @service_id,
                                       'contract_id' => @contract_id_two,
                                       'timestamp'   => '2010-07-26 12:12:00',
                                       'usage'       => {@metric_id => 1}}])
    end
    
    def test_handles_transactions_with_utc_timestamps
      Aggregator.expects(:aggregate).with do |transactions|
        transactions.first[:timestamp] == Time.utc(2010, 5, 7, 18, 11, 25)
      end

      Transactor::ProcessJob.perform([{'service_id'  => @service_id,
                                       'contract_id' => @contract_id_one,
                                       'timestamp'   => '2010-05-07 18:11:25',
                                       'usage'       => {@metric_id => 1}}])
    end

    def test_handles_transactions_with_local_timestamps
      Aggregator.expects(:aggregate).with do |transactions|
        transactions.first[:timestamp] == Time.utc(2010, 5, 7, 11, 11, 25)
      end
      
      Transactor::ProcessJob.perform([{'service_id'  => @service_id,
                                       'contract_id' => @contract_id_one,
                                       'timestamp'   => '2010-05-07 18:11:25 +07:00',
                                       'usage'       => {@metric_id => 1}}])
    end
  end
end
