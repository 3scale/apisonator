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
		
		@storage_cassandra = StorageCassandra.instance(true)
		@storage_cassandra.clear_keyspace!
		
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
    
  
    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + 3)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end                   
    assert_equal 0, Resque.queue(:main).length
    
    ## antoher time bucket has elapsed
    
    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + 6)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end                     
    assert_equal 1, Resque.queue(:main).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + 9)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end                     
    assert_equal 1, Resque.queue(:main).length
  
    ## antoher time bucket has elapsed
  
    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + 10)) do
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
    
    Aggregator.run_stats_for_tests
    
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
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal cont, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
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
    
    Aggregator.run_stats_for_tests
    
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
    
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :minute, '201005071323'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :minute, '201005071323'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
        
    good_enough = time_with_cassandra < time_without_cassandra * 3
    
    if (!good_enough) || true
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
                               
    Aggregator.run_stats_for_tests

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
    
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :minute, '201005071323'))
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :minute, '201005071323'))
    assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    
  end
  
  test 'aggregate takes into account setting the counter value' do 
    ## WIP
    
    if false
    v = []
    10.times do
      v <<   { :service_id     => 1001,
              :application_id => 2001,
              :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
              :usage          => {'3001' => 1}}
      
    end
    
    v <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
             :usage          => {'3001' => '#665'}}
    
    
    v <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
             :usage          => {'3001' => '1'}}
                                                
    Aggregator.aggregate_all(v)
                               
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 666, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
      
    end
  
  end
  
  test 'failed cql batches get stored into redis and processed properly afterwards' do 
    ## WIP
    if false
      ## first one ok,
       
      Aggregator.aggregate_all([{:service_id     => 1001,
                                 :application_id => 2001,
                                 :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                 :usage          => {'3001' => 1}}])

      assert_equal '1', @storage.get(service_key(1001, 3001, :eternity))    
      cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
      assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
          
      assert_equal 0, @storage.llen(Aggregator.failed_batch_cql_key)
      
      ## on the second on we stub the storage_cassandra to simulate a network error or cassandra down
      
      @storage_cassandra.stubs(:execute).raises(Exception.new('bang!'))
      @storage_cassandra.stubs(:add).raises(Exception.new('bang!'))
      @storage_cassandra.stubs(:get).raises(Exception.new('bang!'))

      5.times do 
        Aggregator.aggregate_all([{:service_id     => 1001,
                                  :application_id => 2001,
                                  :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                  :usage          => {'3001' => 1}}])

      end
                                 
      ## remove the stubbing                       
      @storage_cassandra = StorageCassandra.instance(true)                             
                                 
      assert_equal '6', @storage.get(service_key(1001, 3001, :eternity))    
      cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
      assert_equal 1, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

      assert_equal 5, @storage.llen(Aggregator.failed_batch_cql_key)
      
      ## now let's process the failed, one by one...
      
      Aggregator.process_failed_batch_cql()
      
      assert_equal '6', @storage.get(service_key(1001, 3001, :eternity))    
      cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
      assert_equal 2, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

      assert_equal 4, @storage.llen(Aggregator.failed_batch_cql_key)
      
      Aggregator.process_failed_batch_cql()
      
      assert_equal '6', @storage.get(service_key(1001, 3001, :eternity))    
      cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
      assert_equal 3, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

      assert_equal 3, @storage.llen(Aggregator.failed_batch_cql_key)
      
      
      ## or altogether
      
      Aggregator.process_failed_batch_cql(:all => true)
      
      assert_equal '6', @storage.get(service_key(1001, 3001, :eternity))    
      cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(service_key(1001, 3001, :eternity))
      assert_equal 6, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)

      assert_equal 0, @storage.llen(Aggregator.failed_batch_cql_key)
      
    end  
      
  end

  
  test 'aggregate takes into account setting the counter value in the case of failed batches' do 
    ## WIP
    if false
    v = []
    10.times do
      v <<   { :service_id     => 1001,
              :application_id => 2001,
              :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
              :usage          => {'3001' => 1}}
      
    end
    
    v <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
             :usage          => {'3001' => '#665'}}
    
    
    v <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
             :usage          => {'3001' => '1'}}
    
    @storage_cassandra.stubs(:execute).raises(Exception.new('bang!'))
    @storage_cassandra.stubs(:add).raises(Exception.new('bang!'))
    @storage_cassandra.stubs(:get).raises(Exception.new('bang!'))
                                                           
    Aggregator.aggregate_all(v)
    
    @storage_cassandra = StorageCassandra.instance(true)           
    
    ## it failed for cassandra
                           
    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))                             
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal 1, Aggregator.failed_batch_cql_size
    
    Aggregator.process_failed_batch_cql(:all => true)
    
    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))                             
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 666, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal 0, Aggregator.failed_batch_cql_size
    
    assert_equal 0, Aggregator.unprocessable_batch_cql_size
    
    end
        
  end
  
  test 'unprocessable batches get stored in redis' do
    ## WIP
    if false
      
    ## this is ok but empty
  
    @storage.rpush(Aggregator.failed_batch_cql_key, 
                   encode(:payload   => [],
                          :timestamp => Time.now.getutc))
                          
                          
    assert_equal 1, Aggregator.failed_batch_cql_size
    assert_equal 0, Aggregator.unprocessable_batch_cql_size
    
    Aggregator.process_failed_batch_cql(:all => true)
     
    assert_equal 0, Aggregator.failed_batch_cql_size
    assert_equal 0, Aggregator.unprocessable_batch_cql_size
                           
    ## wrong payload
                           
    @storage.rpush(Aggregator.failed_batch_cql_key, 
                   encode(:payload   => "bullshit",
                          :timestamp => Time.now.getutc))              
                                                    
    assert_equal 1, Aggregator.failed_batch_cql_size
    assert_equal 0, Aggregator.unprocessable_batch_cql_size

    begin
      Aggregator.process_failed_batch_cql(:all => true)
      assert false
    rescue Exception => error
      assert true
    end
      
    assert_equal 0, Aggregator.failed_batch_cql_size
    assert_equal 1, Aggregator.unprocessable_batch_cql_size    
    assert_equal encode(:payload   => "bullshit", :timestamp => Time.now.getutc) , @storage.lpop(Aggregator.unprocessable_batch_cql_key)                   
    
    ## nil somewhere

    @storage.rpush(Aggregator.failed_batch_cql_key, 
                   encode(nil))    
                                                    
    assert_equal 1, Aggregator.failed_batch_cql_size
    assert_equal 0, Aggregator.unprocessable_batch_cql_size

    begin
      Aggregator.process_failed_batch_cql(:all => true)
      assert false
    rescue Exception => error
      assert true
    end
      
    assert_equal 0, Aggregator.failed_batch_cql_size
    assert_equal 1, Aggregator.unprocessable_batch_cql_size    
    assert_equal encode(nil) , @storage.lpop(Aggregator.unprocessable_batch_cql_key)
    
   
    ## wrong cql statement 

    @storage.rpush(Aggregator.failed_batch_cql_key, 
                   encode(:payload   => ["UPDATE FAKE SET c=c+1 WHERE key = r;"],
                          :timestamp => Time.now.getutc))

    assert_equal 1, Aggregator.failed_batch_cql_size
    assert_equal 0, Aggregator.unprocessable_batch_cql_size

    begin
      Aggregator.process_failed_batch_cql(:all => true)
      assert false
    rescue Exception => error
      assert true
    end

    assert_equal 0, Aggregator.failed_batch_cql_size
    assert_equal 1, Aggregator.unprocessable_batch_cql_size    
    assert_equal encode(:payload   => ["UPDATE FAKE SET c=c+1 WHERE key = r;"], :timestamp => Time.now.getutc) , @storage.lpop(Aggregator.unprocessable_batch_cql_key)    
    end  
  end
  
  test 'enable and disable cassandra' do
    
    Aggregator.enable_cassandra()
    assert_equal true, Aggregator.cassandra_enabled?
    
    Aggregator.disable_cassandra()
    assert_equal false, Aggregator.cassandra_enabled?
    
    Storage.instance.flushdb()
    assert_equal false, Aggregator.cassandra_enabled?
    
  end
  
  test 'tests behavior delete failed and unprocessable queues' do
    ## WIP  
    if false  
    assert_equal 0, Aggregator.delete_unprocessable_batch_cql
    assert_equal 0, Aggregator.delete_failed_batch_cql
    
    @storage.rpush(Aggregator.failed_batch_cql_key, 
                   encode(:payload   => ["UPDATE FAKE SET c=c+1 WHERE key = r;"],
                          :timestamp => Time.now.getutc))

    assert_equal 1, Aggregator.failed_batch_cql_size
    assert_equal 0, Aggregator.unprocessable_batch_cql_size
    
    assert_equal 0, Aggregator.delete_unprocessable_batch_cql
    assert_equal 1, Aggregator.delete_failed_batch_cql    
    
    assert_equal 0, Aggregator.failed_batch_cql_size
    assert_equal 0, Aggregator.unprocessable_batch_cql_size
    
    Aggregator.process_failed_batch_cql(:all => true)
    
    3.times do 
      @storage.rpush(Aggregator.failed_batch_cql_key, 
                      encode(:payload   => ["UPDATE FAKE SET c=c+1 WHERE key = r;"],
                             :timestamp => Time.now.getutc))
    end
                          
    assert_equal 3, Aggregator.failed_batch_cql_size
    assert_equal 0, Aggregator.unprocessable_batch_cql_size                      
     
    begin
      Aggregator.process_failed_batch_cql()
      assert false
    rescue Exception => error
      assert true
    end
    
    assert_equal 2, Aggregator.failed_batch_cql_size
    assert_equal 1, Aggregator.unprocessable_batch_cql_size
    
    assert_equal 1, Aggregator.delete_unprocessable_batch_cql
    assert_equal 1, Aggregator.delete_failed_batch_cql
    
    assert_equal 0, Aggregator.failed_batch_cql_size
    assert_equal 0, Aggregator.unprocessable_batch_cql_size
    
     Aggregator.process_failed_batch_cql()
    
    end
    
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
    
    Aggregator.run_stats_for_tests()
    
  
  end
  
  
  test 'when cassandra is disabled cassandra does not have to be up and running' do
    ## WIP
    if false 
      
    v = []
    10.times do
      v <<   { :service_id     => 1001,
              :application_id => 2001,
              :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
              :usage          => {'3001' => 1}}

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
    
    ## because cassandra is disabled nothing blows and nothing get logged, it's
    ## like the cassandra code never existed
    assert_equal 0, Aggregator.failed_batch_cql_size
    assert_equal 0, Aggregator.unprocessable_batch_cql_size
    
    assert_equal '10', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))                             
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    ## now, enabled it cassandra and do the same
    
    configuration.cassandra.servers = Array(StorageCassandra::DEFAULT_SERVER)
    configuration.cassandra.keyspace = StorageCassandra::DEFAULT_KEYSPACE
    StorageCassandra.reset_to_nil!
    
    Aggregator.enable_cassandra()
    
    v.each do |item|
      Aggregator.aggregate_all([item])
    end
    
    Aggregator.run_stats_for_tests()
    
    assert_equal 0, Aggregator.failed_batch_cql_size
    assert_equal 0, Aggregator.unprocessable_batch_cql_size

    assert_equal '20', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))                             
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 10, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
      
    end
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
                               
    Aggregator.run_stats_for_tests()
                               
                               
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
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :month,   '20100501'))
    assert_equal 5, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :eternity))
    assert_equal 5, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    Aggregator.aggregate_all([{:service_id     => service.id,
                               :application_id => application.id,
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {@metric_hits.id => 4},
                               :user_id        => "another_user_id_xyz"}])
    
    Aggregator.run_stats_for_tests()
    
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
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :eternity))
    assert_equal 4, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    
  end


  test 'aggregate_all updates application set' do
    Aggregator.aggregate_all([{:service_id     => 1001,
                               :application_id => 2001,
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {'3001' => 1}}])
    
    Aggregator.run_stats_for_tests()
    
    assert_equal ['2001'], @storage.smembers("stats/{service:1001}/cinstances")
  end
    
  test 'aggregate_all does not update service set' do
    assert_no_change :of => lambda { @storage.smembers('stats/services') } do
      Aggregator.aggregate_all([{:service_id     => '1001',
                                 :application_id => '2001',
                                 :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                 :usage          => {'3001' => 1}}])
                                 
      Aggregator.run_stats_for_tests()                           
    end
  end
    
  test 'aggregate_all sets expiration time for volatile keys' do
    Aggregator.aggregate_all([{:service_id     => '1001',
                               :application_id => '2001',
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {'3001' => 1}}])
                               
    Aggregator.run_stats_for_tests()                           

    key = application_key('1001', '2001', '3001', :minute, 201005071323)
    ttl = @storage.ttl(key)

    assert_not_equal -1, ttl
    assert ttl >  0
    assert ttl <= 60
  end

end
