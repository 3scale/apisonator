require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AggregatorTest < Test::Unit::TestCase
  include TestHelpers::StorageKeys

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
  end
  

  test 'aggregate_all increments_all_stats_counters' do
    Aggregator.aggregate_all([{:service_id     => 1001,
                               :application_id => 2001,
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {'3001' => 1}}])

    assert_equal '1', @storage.get(service_key(1001, 3001, :eternity))
    assert_equal '1', @storage.get(service_key(1001, 3001, :month,  '20100501'))
    assert_equal '1', @storage.get(service_key(1001, 3001, :week,   '20100503'))
    assert_equal '1', @storage.get(service_key(1001, 3001, :day,    '20100507'))
    assert_equal '1', @storage.get(service_key(1001, 3001, :hour,   '2010050713'))

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :eternity))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :week,   '20100503'))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :minute, '201005071323'))
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
    assert ttl <= 60
  end
  
  test 'aggregate takes into account setting the counter value' do 
    
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
                               
    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
        
  end
  
  
  
end
