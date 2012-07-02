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
  
  
  test 'benchmark check, not a real failure' do
    
    db = CassandraCQL::Database.new(['127.0.0.1:29160', '127.0.0.1:19160', StorageCassandra::DEFAULT_SERVER], 
                {:keyspace => StorageCassandra::DEFAULT_KEYSPACE}, 
                :retries => 3, :connect_timeout => 3)
    
    db.schema.column_family_names.each do |cf|
      db.execute("truncate #{cf}")
    end
    
    100.times do |cont|
      db.execute("UPDATE Stats SET c1=c1+1 WHERE key=r1")
    
      r = db.execute("SELECT c1 FROM Stats WHERE key=r1")

      value = nil
      r.fetch do |row|
        value = row.to_hash["c1"]
      end
    
      assert_equal cont+1, value
    end
    
    puts "done"
    db.schema.column_family_names.each do |cf|
      db.execute("truncate #{cf}")
    end
    
    
  end
  
  

end
