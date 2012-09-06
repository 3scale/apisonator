require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AggregatorCassandraTest < Test::Unit::TestCase
  include TestHelpers::StorageKeys
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Sequences
  include Backend::StorageHelpers

	def seed_data

		#MASTER_SERVICE_ID = 1

		## for the master
		master_service_id = ThreeScale::Backend.configuration.master_service_id
		Metric.save(
      :service_id => master_service_id,
      :id         => 100,
      :name       => 'hits',
      :children   => [Metric.new(:id => 101, :name => 'transactions/create_multiple'),
                      Metric.new(:id => 102, :name => 'transactions/authorize')])

    Metric.save(
      :service_id => master_service_id,
      :id         => 200,
      :name       => 'transactions')

		## for the provider    

		provider_key = "provider_key"
    service_id   = 1001
    Service.save!(:provider_key => provider_key, :id => service_id)

    # Create master cinstance
    Application.save(:service_id => service_id,
              :id => 2001, :state => :live)
		
    # Create metrics
    @metric_hits = Metric.save(:service_id => service_id, :id => 3001, :name => 'hits')

	end

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
		seed_data()
		
		## all the test will have to disable the flag before finishing,
		## in theory not needed since we always do flush, if not
		## @storage.del("cassandra_enabled")
 		Aggregator.enable_cassandra()
 		Aggregator.activate_cassandra()
		
		@storage_cassandra = StorageCassandra.instance(true)
		@storage_cassandra.clear_keyspace!
		
		Resque.reset!
		Aggregator.reset_current_bucket!
		
		## stubbing the airbreak, not working on tests
		Airbrake.stubs(:notify).returns(true)
		
		
  end
  
  test 'Stats jobs get properly enqueued' do 
    
    
    assert_equal 0, Resque.queue(:main).length
    
    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end  
    assert_equal 0, Resque.queue(:main).length
    
  
    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (Aggregator.stats_bucket_size/2).to_i)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end                   
    assert_equal 0, Resque.queue(:main).length
    
    ## antoher time bucket has elapsed
    
    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (Aggregator.stats_bucket_size*1.5).to_i)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end                     
    assert_equal 1, Resque.queue(:main).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (Aggregator.stats_bucket_size*1.9).to_i)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end                     
    assert_equal 1, Resque.queue(:main).length
  
    ## antoher time bucket has elapsed
  
    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (Aggregator.stats_bucket_size*2).to_i)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end                     
    assert_equal 2, Resque.queue(:main).length
  
  end
  
  test 'benchmark check, not a real failure if happens' do
    
    cont = 1000
    
    t = Time.now
    
    cont.times do 
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])                       
    end
    
    Aggregator.schedule_one_stats_job
    Resque.run!
    
    assert_equal 0, Aggregator.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length
    
    time_with_cassandra = Time.now-t
    
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :eternity))    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :month,  '20100501'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :month,  '20100501'))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :week,   '20100503'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :week,   '20100503'))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
     
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :day,    '20100507'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :day,    '20100507'))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :hour,   '2010050713'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    ## it's for the service, so no row/col keys
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal true, cassandra_row_key.nil? || cassandra_col_key.nil?  
        
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :eternity))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :eternity))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :week,   '20100503'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :week,   '20100503'))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :day,    '20100507'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    ## it's for the app, but not hour, so no row/col keys
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal true, cassandra_row_key.nil? || cassandra_col_key.nil?  
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    ## here it's fine for the StatsInverted, application and hour
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal false, cassandra_row_key.nil? || cassandra_col_key.nil?  
    assert_equal cont, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :minute, '201005071323'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :minute, '201005071323'))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
      
    @storage = Storage.instance(true)
    @storage.flushdb
		seed_data()
				
		@storage_cassandra = StorageCassandra.instance(true)
		@storage_cassandra.clear_keyspace!
		
		cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))		
		assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    t = Time.now
    
    cont.times do 
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
                                
    end
    
    
    Aggregator.schedule_one_stats_job()
    Resque.run!
    
    assert_equal 0, Aggregator.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length
    
    time_without_cassandra = Time.now-t
    
    
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :eternity))    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :month,  '20100501'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :month,  '20100501'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :week,   '20100503'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :week,   '20100503'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
     
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :day,    '20100507'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :day,    '20100507'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :hour,   '2010050713'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :eternity))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :eternity))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :week,   '20100503'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :week,   '20100503'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :day,    '20100507'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :minute, '201005071323'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :minute, '201005071323'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
        
    good_enough = time_with_cassandra < time_without_cassandra * 1.5
    
    if (!good_enough)
      puts "\nwith    cassandra: #{time_with_cassandra}s"
      puts "without cassandra: #{time_without_cassandra}s\n"
    end
      
    assert_equal true, good_enough
    
    
    
  end


  test 'aggregate_all increments_all_stats_counters' do
    Aggregator.aggregate_all([{:service_id     => 1001,
                               :application_id => 2001,
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {'3001' => 1}}])
                               
    assert_equal 0 , Resque.queue(:main).length
    Aggregator.schedule_one_stats_job
    assert_equal 1 , Resque.queue(:main).length
    Resque.run!  
    assert_equal 0 , Resque.queue(:main).length
    

    assert_equal '1', @storage.get(service_key(1001, 3001, :eternity))    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

    assert_equal '1', @storage.get(service_key(1001, 3001, :month,  '20100501'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :month,  '20100501'))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal '1', @storage.get(service_key(1001, 3001, :week,   '20100503'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :week,   '20100503'))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
     
    assert_equal '1', @storage.get(service_key(1001, 3001, :day,    '20100507'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :day,    '20100507'))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal '1', @storage.get(service_key(1001, 3001, :hour,   '2010050713'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :eternity))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :eternity))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :week,   '20100503'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :week,   '20100503'))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :day,    '20100507'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 1, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)
    
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :minute, '201005071323'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :minute, '201005071323'))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    
  end
  
  test 'aggregate takes into account setting the counter value' do 
   
    v = []
    10.times do
      v <<   { :service_id     => 1001,
              :application_id => 2001,
              :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
              :usage          => {'3001' => 1}}
      
    end
    
    Aggregator.aggregate_all(v)
    
    Aggregator.schedule_one_stats_job
    Resque.run!
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 10, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 10, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)
    
    
    
    v = []
    v  <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
             :usage          => {'3001' => '#665'}}
    
    Aggregator.aggregate_all(v)

    Aggregator.schedule_one_stats_job
    Resque.run!

    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 665, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 665, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)


    v = []
    v <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
             :usage          => {'3001' => '1'}}
                                                
    Aggregator.aggregate_all(v)
    
    Aggregator.schedule_one_stats_job
    Resque.run!
                               
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 666, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 666, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)
    
  end
  
  test 'direct test of get_old_buckets_to_process' do 
    ## this should go as unit test of StatsBatcher
    
    @storage.zadd(Aggregator.changed_keys_key,"20121010102100","20121010102100")
    assert_equal [], Aggregator.get_old_buckets_to_process("20121010102100")
    
    assert_equal ["20121010102100"], Aggregator.get_old_buckets_to_process("20121010102120")
    
    assert_equal [], Aggregator.get_old_buckets_to_process("20121010102120")
    
    
    @storage.del(Aggregator.changed_keys_key)
    
    100.times do |i|
      @storage.zadd(Aggregator.changed_keys_key,i,i.to_s)
    end
    
    assert_equal [], Aggregator.get_old_buckets_to_process("0")
    
    v = Aggregator.get_old_buckets_to_process("1")
    assert_equal v, ["0"]
    
    v = Aggregator.get_old_buckets_to_process("1")
    assert_equal [], v
    
    v = Aggregator.get_old_buckets_to_process("2")
    assert_equal v, ["1"]
    
    v = Aggregator.get_old_buckets_to_process("2")
    assert_equal [], v
    
    v = Aggregator.get_old_buckets_to_process("11")
    assert_equal 9, v.size
    assert_equal ["2", "3", "4", "5", "6", "7", "8", "9", "10"], v
    
    v = Aggregator.get_old_buckets_to_process
    assert_equal 89, v.size
    
    v = Aggregator.get_old_buckets_to_process
    assert_equal [], v
  end
  
  test 'concurrency test on get_old_buckets_to_process' do
  
    ## this should go as unit test of StatsBatcher
    100.times do |i|
      @storage.zadd(Aggregator.changed_keys_key,i,i.to_s)
    end
  
    10.times do |i|
      threads = []
      cont = 0
      
      20.times do |j|
        threads << Thread.new {
          r = Redis.new(:db => 2)
          v = Aggregator.get_old_buckets_to_process(((i+1)*10).to_s,r)
          
          assert (v.size==0 || v.size==10)
          
          cont=cont+1 if v.size==10
          
          
        }
      end
      
      threads.each do |t|
        t.join
      end
      
      assert_equal 1, cont
      
    end
    
  end
  
  
  test 'bucket keys are properly assigned' do 
    
    timestamp = Time.now.utc - 1000
    assert_equal 0, Aggregator.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length 
      
    5.times do |cont|
      
      bucket_key = timestamp.beginning_of_bucket(Aggregator.stats_bucket_size).to_not_compact_s
      
      Timecop.freeze(timestamp) do 
        Aggregator.aggregate_all([{:service_id     => 1001,
                                  :application_id => 2001,
                                  :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                  :usage          => {'3001' => 1}}])
        
      end
      
      assert_equal cont+1, Aggregator.pending_buckets.size
      assert Aggregator.pending_buckets.member?(bucket_key)
      assert_equal cont, Resque.queue(:main).length  
      
      timestamp = timestamp + Aggregator.stats_bucket_size
                                    
    end
    
    assert_equal 5, Aggregator.pending_buckets.size
    assert_equal 0, Aggregator.failed_buckets.size
    
    sorted_set = Aggregator.pending_buckets.sort
    
    4.times do |i|
      buckets = Aggregator.get_old_buckets_to_process(sorted_set[i+1])
      assert_equal 1, buckets.size
      assert_equal sorted_set[i], buckets.first
    end
    
    assert_equal 1, Aggregator.pending_buckets.size
    buckets = Aggregator.get_old_buckets_to_process
    assert_equal 1, buckets.size
    assert_equal sorted_set[4], buckets.first
    
  end
  
  test 'time bucket already inserted' do
    
      timestamp = Time.utc(2010, 5, 7, 13, 23, 33)
    
      assert_equal false, Aggregator.time_bucket_already_inserted?(timestamp.beginning_of_bucket(Aggregator.stats_bucket_size).to_not_compact_s)
     
      Timecop.freeze(timestamp) do 
        Aggregator.aggregate_all([{:service_id     => 1001,
                                    :application_id => 2001,
                                    :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                    :usage          => {'3001' => 1}}])

      end

      Aggregator.schedule_one_stats_job
      Resque.run! 
      
      assert_equal 0, Resque.queue(:main).length
      assert_equal 0, Aggregator.pending_buckets.size 
      
      
      assert_equal '1', @storage.get(service_key(1001, 3001, :eternity))    
      cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
      assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

      assert_equal true, Aggregator.time_bucket_already_inserted?(timestamp.beginning_of_bucket(Aggregator.stats_bucket_size).to_not_compact_s)
    
  end
  
  test 'failed cql batches get stored into redis and processed properly afterwards' do 
  
    ## first one ok,
    Aggregator.aggregate_all([{:service_id     => 1001,
                               :application_id => 2001,
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {'3001' => 1}}])

    assert_equal 1, Aggregator.pending_buckets.size
    Aggregator.schedule_one_stats_job
    Resque.run!
    assert_equal 0, Aggregator.pending_buckets.size  
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator.failed_buckets.size

    assert_equal '1', @storage.get(service_key(1001, 3001, :eternity))    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
          
    ## on the second on we stub the storage_cassandra to simulate a network error or cassandra down
    
    @storage_cassandra.stubs(:execute).raises(Exception.new('bang!'))
    @storage_cassandra.stubs(:execute_cql_query).raises(Exception.new('bang!'))
    @storage_cassandra.stubs(:add).raises(Exception.new('bang!'))
    @storage_cassandra.stubs(:get).raises(Exception.new('bang!'))


    timestamp = Time.now.utc - 1000
    
    5.times do 
            
      Timecop.freeze(timestamp) do 
        Aggregator.aggregate_all([{:service_id     => 1001,
                                  :application_id => 2001,
                                  :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                  :usage          => {'3001' => 1}}])
        
      end
      
      timestamp = timestamp + Aggregator.stats_bucket_size                              
    end
  
    ## failed_buckets is 0 because nothing has been tried and hence failed yet
    assert_equal 0, Aggregator.failed_buckets.size
    assert_equal 0, Aggregator.failed_buckets_at_least_once.size
    assert_equal 5, Aggregator.pending_buckets.size
    
    Aggregator.schedule_one_stats_job
    Resque.run!  
    assert_equal 0, Resque.queue(:main).length
    
    ## buckets went to the failed state
    assert_equal 0, Aggregator.pending_buckets.size 
    assert_equal 5, Aggregator.failed_buckets.size
    assert_equal 5, Aggregator.failed_buckets_at_least_once.size
    
    
                               
    ## remove the stubbing                       
    @storage_cassandra = StorageCassandra.instance(true)
                                   
    assert_equal '6', @storage.get(service_key(1001, 3001, :eternity))    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

    ## now let's process the failed, one by one...
    
    v = Aggregator.failed_buckets
    Aggregator.save_to_cassandra(v.first)
    
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator.pending_buckets.size
    assert_equal 4, Aggregator.failed_buckets.size
    assert_equal 5, Aggregator.failed_buckets_at_least_once.size
    
      
    assert_equal '6', @storage.get(service_key(1001, 3001, :eternity))    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
    assert_equal 2, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

    ## or altogether

    v = Aggregator.failed_buckets
    v.each do |bucket|
      Aggregator.save_to_cassandra(bucket)
    end
  
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator.pending_buckets.size
    assert_equal 0, Aggregator.failed_buckets.size
    assert_equal 5, Aggregator.failed_buckets_at_least_once.size
    
    
    assert_equal '6', @storage.get(service_key(1001, 3001, :eternity))    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
    assert_equal 6, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
  
    assert_equal [], Aggregator.repeated_batches
    
  end

  
  test 'aggregate takes into account setting the counter value in the case of failed batches' do 


    @storage_cassandra.stubs(:execute).raises(Exception.new('bang!'))
    @storage_cassandra.stubs(:execute_cql_query).raises(Exception.new('bang!'))
    @storage_cassandra.stubs(:add).raises(Exception.new('bang!'))
    @storage_cassandra.stubs(:get).raises(Exception.new('bang!'))
    
    v = []
    10.times do
      v <<   { :service_id     => 1001,
              :application_id => 2001,
              :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
              :usage          => {'3001' => 1}}
      
    end
    
    Aggregator.aggregate_all(v)
    Aggregator.schedule_one_stats_job
    Resque.run!
    
    v = []
    v <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
             :usage          => {'3001' => '#665'}}
    
    Aggregator.aggregate_all(v)
    Aggregator.schedule_one_stats_job
    Resque.run!
    
    v = []
    v <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
             :usage          => {'3001' => '1'}}
    

                                                           
    Aggregator.aggregate_all(v)
    Aggregator.schedule_one_stats_job
    Resque.run!
    
    ## it failed for cassandra
    
    @storage_cassandra = StorageCassandra.instance(true)    
        
    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))                             
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)    
    
    assert_equal 0, Aggregator.pending_buckets.size
    assert_equal 1, Aggregator.failed_buckets.size
    assert_equal 1, Aggregator.failed_buckets_at_least_once.size
    
    v = Aggregator.failed_buckets
    Aggregator.save_to_cassandra(v.first)

    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))                             
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 666, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 666, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)
    
    assert_equal [], Aggregator.repeated_batches
        
  end
  
  
  test 'enable and disable cassandra' do
    
    Aggregator.enable_cassandra()
    assert_equal true, Aggregator.cassandra_enabled?
    
    Aggregator.disable_cassandra()
    assert_equal false, Aggregator.cassandra_enabled?
    
    Storage.instance.flushdb()
    assert_equal false, Aggregator.cassandra_enabled?
    
  end
  
  test 'activate and deactive cassandra' do
    
    Aggregator.activate_cassandra()
    assert_equal true, Aggregator.cassandra_active?
    
    Aggregator.deactivate_cassandra()
    assert_equal false, Aggregator.cassandra_active?
    
    Storage.instance.flushdb()
    assert_equal false, Aggregator.cassandra_active?
    
  end
  
  test 'when cassandra is deactivated buckets are filled but nothing gets saved' do 

     Aggregator.deactivate_cassandra()

     v = []
     10.times do
       v <<   { :service_id     => 1001,
               :application_id => 2001,
               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
               :usage          => {'3001' => 1}}

     end

     Aggregator.aggregate_all(v)

     assert_equal 0, Resque.queue(:main).length
     assert_equal 1, Aggregator.pending_buckets.size

     Aggregator.schedule_one_stats_job
     Resque.run!

     assert_equal 0, Resque.queue(:main).length
     assert_equal 1, Aggregator.pending_buckets.size

     Aggregator.activate_cassandra()
     
     Aggregator.schedule_one_stats_job
     Resque.run!

     assert_equal 0, Resque.queue(:main).length
     assert_equal 0, Aggregator.pending_buckets.size

   end
  
  
  test 'when cassandra is disabled nothing gets logged' do 
    
    Aggregator.disable_cassandra()
  
    v = []
    10.times do
      v <<   { :service_id     => 1001,
              :application_id => 2001,
              :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
              :usage          => {'3001' => 1}}
      
    end
    
    Aggregator.aggregate_all(v)
    
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator.pending_buckets.size
    
    Aggregator.schedule_one_stats_job
    Resque.run!
    
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator.pending_buckets.size
    
    assert_equal [], Aggregator.repeated_batches
    
    
  end
  
  
  test 'when cassandra is disabled cassandra does not have to be up and running, but stats get lost during the disabling period' do
       
    v = []
    Timecop.freeze(Time.utc(2010, 5, 7, 13, 23, 33)) do
      10.times do  
        v <<   { :service_id     => 1001,
                :application_id => 2001,
                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                :usage          => {'3001' => 1}}
      end         
    end
    
    bkp_configuration = configuration.clone()
     
    configuration.cassandra.servers = ["localhost:9090"]
    configuration.cassandra.keyspace = StorageCassandra::DEFAULT_KEYSPACE
    
    ## we set to nil the connection to cassandra
    StorageCassandra.reset_to_nil!
  
    ## now we disable it cassandra
    Aggregator.disable_cassandra()
      
    v.each do |item|
      Aggregator.aggregate_all([item])
    end
    
    Aggregator.pending_buckets.size.times do 
      Aggregator.schedule_one_stats_job
    end
    Resque.run!
    
    ## because cassandra is disabled nothing blows and nothing get logged, it's
    ## like the cassandra code never existed
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator.pending_buckets.size
    
    assert_equal '10', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))                             
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)    
    
    ## now, enabled it cassandra and do the same
    
    configuration.cassandra.servers = Array(StorageCassandra::DEFAULT_SERVER)
    configuration.cassandra.keyspace = StorageCassandra::DEFAULT_KEYSPACE
    StorageCassandra.reset_to_nil!
    
    Aggregator.enable_cassandra()
    
    v.each do |item|
      Aggregator.aggregate_all([item])
    end
    
    assert_equal 1, Aggregator.pending_buckets.size
    
    Aggregator.pending_buckets.size.times do
      Aggregator.schedule_one_stats_job()
    end
    Resque.run!
    
    assert_equal 0, Aggregator.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length
    
    assert_equal '20', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))                             
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 10, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 10, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)    
    
    assert_equal [], Aggregator.repeated_batches
    
    ## cassandra and redis are out of sync, cassandra has 10 but redis 20 because the first 10 hits cassandra was disabled. 
    ## disabling cassandra is super dangerous, only in PANIC MODE
      
  end

  test 'when cassandra is deactivated cassandra does not have to be up and running, but stats do NOT get lost during the deactivation period' do
       
    v = []
    Timecop.freeze(Time.utc(2010, 5, 7, 13, 23, 33)) do
      10.times do  
        v <<   { :service_id     => 1001,
                :application_id => 2001,
                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                :usage          => {'3001' => 1}}
      end         
    end
    
    bkp_configuration = configuration.clone()
     
    configuration.cassandra.servers = ["localhost:9090"]
    configuration.cassandra.keyspace = StorageCassandra::DEFAULT_KEYSPACE
    
    ## we set to nil the connection to cassandra
    StorageCassandra.reset_to_nil!
  
    ## now we disable it cassandra
    Aggregator.deactivate_cassandra()
      
    v.each do |item|
      Aggregator.aggregate_all([item])
    end
    
    assert_equal 1, Aggregator.pending_buckets.size
    
    Aggregator.schedule_one_stats_job
    Resque.run!
    
    ## because cassandra is deactivated nothing blows but it gets logged waiting for cassandra
    ## to be in place again
    assert_equal 0, Resque.queue(:main).length
    assert_equal 1, Aggregator.pending_buckets.size
    
    assert_equal '10', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))                             
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)
    
    
    ## now, enabled it cassandra and do the same
    
    configuration.cassandra.servers = Array(StorageCassandra::DEFAULT_SERVER)
    configuration.cassandra.keyspace = StorageCassandra::DEFAULT_KEYSPACE
    StorageCassandra.reset_to_nil!
    
    Aggregator.activate_cassandra()
    
    assert_equal 1, Aggregator.pending_buckets.size
    
    sleep(Aggregator.stats_bucket_size)
    
    v.each do |item|
      Aggregator.aggregate_all([item])
    end
    
    assert_equal 2, Aggregator.pending_buckets.size
    
    Aggregator.schedule_one_stats_job()
    Resque.run!
    
    assert_equal 0, Aggregator.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length
    
    assert_equal '20', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))                             
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 20, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 20, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)
          
    assert_equal [], Aggregator.repeated_batches
    
  end


  test 'applications with end user plans (user_id) get recorded properly' do
    
    default_user_plan_id = next_id
    default_user_plan_name = "user plan mobile"
    
    service = Service.save!(:provider_key => @provider_key, :id => next_id)
  
    service.user_registration_required = false
    service.default_user_plan_name = default_user_plan_name
    service.default_user_plan_id = default_user_plan_id
    service.save!

    application = Application.save(:service_id => service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name,
                                    :user_required => true)
                                    
    Aggregator.aggregate_all([{:service_id     => service.id,
                               :application_id => application.id,
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {@metric_hits.id => 5},
                               :user_id        => "user_id_xyz"}])
                               
    Aggregator.pending_buckets.size.times do |cont|
      Aggregator.schedule_one_stats_job()
    end
    Resque.run!

    assert_equal 0, Aggregator.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length
                               
                               
    assert_equal '5', @storage.get(application_key(service.id, application.id, @metric_hits.id, :hour,   '2010050713'))                                                                  
    assert_equal '5', @storage.get(application_key(service.id, application.id, @metric_hits.id, :month,   '20100501'))                                                                  
    assert_equal '5', @storage.get(application_key(service.id, application.id, @metric_hits.id, :eternity))                                                                  
    
    assert_equal '5', @storage.get(service_key(service.id, @metric_hits.id, :hour,   '2010050713'))                                                                  
    assert_equal '5', @storage.get(service_key(service.id, @metric_hits.id, :month,   '20100501'))                                                                  
    assert_equal '5', @storage.get(service_key(service.id, @metric_hits.id, :eternity))                                                                  
    
    assert_equal '5', @storage.get(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :hour,   '2010050713'))                                                                  
    assert_equal '5', @storage.get(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :month,   '20100501'))                                                                  
    assert_equal '5', @storage.get(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :eternity))

    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(service.id, application.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal 5, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(service.id, application.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal 5, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(service.id, application.id, @metric_hits.id, :month,   '20100501'))
    assert_equal 5, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(service.id, application.id, @metric_hits.id, :eternity))
    assert_equal 5, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(service.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal 5, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(service.id, @metric_hits.id, :month,   '20100501'))
    assert_equal 5, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(service.id, @metric_hits.id, :eternity))
    assert_equal 5, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :hour,   '2010050713'))
    assert_equal 5, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    ## no StatsInverted for uinstances
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :hour,   '2010050713'))
    assert_equal true, cassandra_row_key.nil? || cassandra_col_key.nil?
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :month,   '20100501'))
    assert_equal 5, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :eternity))
    assert_equal 5, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    Aggregator.aggregate_all([{:service_id     => service.id,
                               :application_id => application.id,
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {@metric_hits.id => 4},
                               :user_id        => "another_user_id_xyz"}])
    
    Aggregator.pending_buckets.size.times do
      Aggregator.schedule_one_stats_job()
    end
    Resque.run!
    
    assert_equal 0, Aggregator.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length
    
    
    assert_equal '9', @storage.get(application_key(service.id, application.id, @metric_hits.id, :hour,   '2010050713'))                                                                  
    assert_equal '9', @storage.get(application_key(service.id, application.id, @metric_hits.id, :month,   '20100501'))                                                                  
    assert_equal '9', @storage.get(application_key(service.id, application.id, @metric_hits.id, :eternity))                                                                  

    assert_equal '9', @storage.get(service_key(service.id, @metric_hits.id, :hour,   '2010050713'))                                                                  
    assert_equal '9', @storage.get(service_key(service.id, @metric_hits.id, :month,   '20100501'))                                                                  
    assert_equal '9', @storage.get(service_key(service.id, @metric_hits.id, :eternity))                                                                  

    assert_equal '4', @storage.get(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :hour,   '2010050713'))                                                                  
    assert_equal '4', @storage.get(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :month,   '20100501'))                                                                  
    assert_equal '4', @storage.get(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :eternity))
    
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(service.id, application.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal 9, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(application_key(service.id, application.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal 9, @storage_cassandra.get(:StatsInverted, cassandra_row_key, cassandra_col_key)
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(service.id, application.id, @metric_hits.id, :month,   '20100501'))
    assert_equal 9, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(service.id, application.id, @metric_hits.id, :eternity))
    assert_equal 9, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(service.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal 9, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(service.id, @metric_hits.id, :month,   '20100501'))
    assert_equal 9, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(service.id, @metric_hits.id, :eternity))
    assert_equal 9, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :hour,   '2010050713'))
    assert_equal 4, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :month,   '20100501'))
    assert_equal 4, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    # no StatsInverted for not :hour or uinstance
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key_inverted(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :eternity))
    assert_equal true, cassandra_row_key.nil? || cassandra_col_key.nil?
        
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :eternity))
    assert_equal 4, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal [], Aggregator.repeated_batches
    
    
  end

  test 'delete all buckets and keys' do 
  
    @storage_cassandra.stubs(:execute).raises(Exception.new('bang!'))
    @storage_cassandra.stubs(:execute_cql_query).raises(Exception.new('bang!'))
    @storage_cassandra.stubs(:add).raises(Exception.new('bang!'))
    @storage_cassandra.stubs(:get).raises(Exception.new('bang!'))


    timestamp = Time.now.utc - 1000
    
    5.times do 
            
      Timecop.freeze(timestamp) do 
        Aggregator.aggregate_all([{:service_id     => 1001,
                                  :application_id => 2001,
                                  :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                  :usage          => {'3001' => 1}}])
        
      end
      
      timestamp = timestamp + Aggregator.stats_bucket_size                              
    end
  
    ## failed_buckets is 0 because nothing has been tried and hence failed yet
    assert_equal 0, Aggregator.failed_buckets.size
    assert_equal 5, Aggregator.pending_buckets.size
    
    Aggregator.schedule_one_stats_job
    Resque.run!  
    assert_equal 0, Resque.queue(:main).length
    
    ## jobs did not do anything because cassandra connection failed
    assert_equal 0, Aggregator.pending_buckets.size
    assert_equal 5, Aggregator.failed_buckets_at_least_once.size 
    assert_equal 5, Aggregator.failed_buckets.size
  
    v = @storage.keys("keys_changed:*")
    assert_equal true, v.size > 0
    
    v = @storage.keys("copied:*")
    assert_equal true, v.size > 0
    
    Aggregator.delete_all_buckets_and_keys_only_as_rake!({:silent => true})
    
    v = @storage.keys("copied:*")
    assert_equal 0, v.size
    
    v = @storage.keys("keys_changed:*")
    assert_equal 0, v.size 
    
    assert_equal 0, Aggregator.pending_buckets.size 
    assert_equal 0, Aggregator.failed_buckets.size
    assert_equal 0, Aggregator.failed_buckets_at_least_once.size
    
    
  end

  test 'aggregate_all updates application set' do
    Aggregator.aggregate_all([{:service_id     => 1001,
                               :application_id => 2001,
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {'3001' => 1}}])
    
    assert_equal ['2001'], @storage.smembers("stats/{service:1001}/cinstances")
  end
    
  test 'aggregate_all does not update service set' do
    assert_no_change :of => lambda { @storage.smembers('stats/services') } do
      Aggregator.aggregate_all([{:service_id     => '1001',
                                 :application_id => '2001',
                                 :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                 :usage          => {'3001' => 1}}])                    
    end
  end
    
  test 'aggregate_all sets expiration time for volatile keys' do
    Aggregator.aggregate_all([{:service_id     => '1001',
                               :application_id => '2001',
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {'3001' => 1}}])
                               

    key = application_key('1001', '2001', '3001', :minute, 201005071323)
    ttl = @storage.ttl(key)

    assert_not_equal -1, ttl
    assert ttl >  0
    assert ttl <= 180
  end

end
