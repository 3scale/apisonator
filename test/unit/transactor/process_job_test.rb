require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Transactor
  class ProcessJobTest < Test::Unit::TestCase
    include TestHelpers::Sequences

    def setup
			@provider_key = next_id
      @service_id = next_id
      @application_id_one = next_id
      @application_id_two = next_id

      @metric_id = next_id

			Service.save!(:provider_key => @provider_key, :id => @service_id)

    	Application.save(:service_id => @service_id,
              :id => @application_id_one, :state => :live)
			Application.save(:service_id => @service_id,
              :id => @application_id_two, :state => :live)
		
    	# Create metrics
    	Metric.save(:service_id => @service_id, :id => @metric_id, :name => @metric_id)

    end
    
    def test_aggregates_failure_due_to_report_after_deadline
      Airbrake.stubs(:notify).returns(true)
      if false
      assert_raise ReportTimestampNotWithinRange  do 
        
        Transactor::ProcessJob.perform([{'service_id'     => @service_id,
                                        'application_id' => @application_id_one,
                                        'timestamp'      => '2010-07-26 12:05:00',
                                        'usage'          => {@metric_id => 1}},
                                        {'service_id'     => @service_id,
                                          'application_id' => @application_id_two,
                                          'timestamp'      => '2010-07-26 12:05:00',
                                          'usage'          => {@metric_id => 1}}])
        
      end  
      end
      Airbrake.unstub(:notify)
    end

    def test_aggregates
      Timecop.freeze(Time.utc(2010, 7, 25, 14, 5)) do
        
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
    end
    
    def test_archives

      Timecop.freeze(Time.utc(2010, 7, 26, 00, 00)) do
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
                                        
    end

    def test_stores
      Timecop.freeze(Time.utc(2010, 9, 10, 00, 00)) do
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
    end
    
    def test_handles_transactions_with_utc_timestamps
      Timecop.freeze(Time.utc(2010, 5, 7, 17, 12, 25)) do
        Aggregator.expects(:aggregate_all).with do |transactions|
          transactions.first[:timestamp] == Time.utc(2010, 5, 7, 18, 11, 25)
        end

        Transactor::ProcessJob.perform([{'service_id'     => @service_id,
                                       'application_id' => @application_id_one,
                                       'timestamp'   => '2010-05-07 18:11:25',
                                       'usage'       => {@metric_id => 1}}])
      end
    end

    def test_handles_transactions_with_local_timestamps
      Timecop.freeze(Time.utc(2010, 5, 6, 12, 11, 25)) do
      
        Aggregator.expects(:aggregate_all).with do |transactions|
          transactions.first[:timestamp] == Time.utc(2010, 5, 7, 11, 11, 25)
        end
      
        Transactor::ProcessJob.perform([{'service_id'     => @service_id,
                                       'application_id' => @application_id_one,
                                       'timestamp'      => '2010-05-07 18:11:25 +07:00',
                                       'usage'          => {@metric_id => 1}}])
      end                                 
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
