require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class CassandraCqlClientBehaviorTest < Test::Unit::TestCase
  include TestHelpers::StorageKeys
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
    Metric.save(:service_id => service_id, :id => 3001, :name => 'hits')

	end
	
	def create_massive_batch(num)

    str = "BEGIN BATCH "
    num.times do |i|
      str << "UPDATE Stats SET 'col#{i}'='col#{i}'+1 WHERE key = row#{i}; "
    end
    str << "APPLY BATCH;"

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
		
  end
  
   
  test 'not getting a timeout because the load was too high' do
  
    db = CassandraCQL::Database.new([StorageCassandra::DEFAULT_SERVER], 
              {:keyspace => StorageCassandra::DEFAULT_KEYSPACE},
              StorageCassandra::THRIFT_OPTIONS)
              
    assert_equal nil, @storage_cassandra.get(:Stats, "row1", "col1")
    sentence = create_massive_batch(20000)
  
    db.execute_cql_query(sentence)
    
    assert_equal 1, @storage_cassandra.get(:Stats, "row1", "col1")
    assert_equal 1, @storage_cassandra.get(:Stats, "row1000", "col1000")
    
  end
    
  test 'getting a timeout because the load was too high' do
  
    db = CassandraCQL::Database.new([StorageCassandra::DEFAULT_SERVER], 
              {:keyspace => StorageCassandra::DEFAULT_KEYSPACE},
              :timeout => 0.5)
              
    assert_equal nil, @storage_cassandra.get(:Stats, "row1", "col1")
    
    sentence = create_massive_batch(20000)
    
    assert_raise CassandraCQL::Thrift::Client::TransportException do
      db.execute_cql_query(sentence)
    end
    
    assert_equal nil, @storage_cassandra.get(:Stats, "row1", "col1")
    
    ## WARNING: if we wait long enough 
    sleep 10.0
    ## the values will magically appear :-/ That's bad. That's why the timeout
    ## for only execute_cql_query (writes) is removed.
    assert_equal 1, @storage_cassandra.get(:Stats, "row1", "col1")
    
  end
  
  test 'retries >= servers - 1 are necessary, the are also used to check for servers availability' do 
    
    assert_raise CassandraCQL::Thrift::Client::TransportException do
    ## beats me why does not raise NoLiveServers    

      10.times do 
        db = CassandraCQL::Database.new(['127.0.0.1:29160', '127.0.0.1:19160', StorageCassandra::DEFAULT_SERVER], 
                 {:keyspace => StorageCassandra::DEFAULT_KEYSPACE}, :retries => 1)
    
      end
    
    end
    
    ## because there are 3 servers, and 2 retries + original request. It will not blow. 
    10.times do 
      db = CassandraCQL::Database.new(['127.0.0.1:29160', '127.0.0.1:19160', StorageCassandra::DEFAULT_SERVER], 
                 {:keyspace => StorageCassandra::DEFAULT_KEYSPACE}, :retries => 2)
    
    end
    
  end
  
    
  
  test 'benchmark check, not a real failure' do
    
    db = nil
    
    10.times do 
      
      db = CassandraCQL::Database.new(['127.0.0.1:29160', '127.0.0.1:19160', StorageCassandra::DEFAULT_SERVER], 
                  {:keyspace => StorageCassandra::DEFAULT_KEYSPACE}, StorageCassandra::THRIFT_OPTIONS)
                
      assert_not_nil db
      
    end
    
    
    db.schema.column_family_names.each do |cf|
      db.execute_cql_query("truncate #{cf}")
    end
    
    100.times do |cont|
      db.execute_cql_query("UPDATE Stats SET c1=c1+1 WHERE key=r1")
    
      r = db.execute("SELECT c1 FROM Stats WHERE key=r1")

      value = nil
      r.fetch do |row|
        value = row.to_hash["c1"]
      end
    
      assert_equal cont+1, value
    end
    
    puts "done"
    db.schema.column_family_names.each do |cf|
      db.execute_cql_query("truncate #{cf}")
    end
    
    
  end
  
  

end
