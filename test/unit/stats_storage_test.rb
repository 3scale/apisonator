require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StatsStorageTest < Test::Unit::TestCase
  include TestHelpers::StorageKeys
  include TestHelpers::Sequences
  include TestHelpers::Fixtures
  
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    seed_data()
  end

  test 'saves the stats when when doing aggregation' do

    Aggregator.aggregate_all([{:service_id     => 1001,
                             :application_id => 2001,
                             :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                             :usage          => {'3001' => 1}}])

    
    
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :month,   '20100501'))
    assert_equal '1', @storage.get(service_key(1001, 3001, :month,  '20100501'))
    
    ## 7 for the cinstance (1 for each time eternity, year, month, week, day, hour, min
    ## and 5 for the service (does not have min or year)
    assert_equal 12, StatsStorage.stats_count(1001)
    list = StatsStorage.stats(1001)
    assert_equal list.size, StatsStorage.stats_count(1001)
        
    assert_equal true, list.include?(application_key(1001, 2001, 3001, :month,   '20100501'))
    assert_equal true, list.include?(service_key(1001, 3001, :month,  '20100501'))
    

    ## nothing should changed, since the no new metrics have to be generated, just 10 seconds from last
    Aggregator.aggregate_all([{:service_id     => 1001,
                              :application_id => 2001,
                              :timestamp      => Time.utc(2010, 5, 7, 13, 23, 43),
                              :usage          => {'3001' => 1}}])
    
    assert_equal list, StatsStorage.stats(1001)
      
    assert_equal '2', @storage.get(application_key(1001, 2001, 3001, :month,   '20100501'))
    assert_equal '2', @storage.get(service_key(1001, 3001, :month,  '20100501'))
    
    ## new metrics will be generated, it's one hour later than last one
    Aggregator.aggregate_all([{:service_id     => 1001,
                               :application_id => 2001,
                               :timestamp      => Time.utc(2010, 5, 7, 14, 23, 43),
                               :usage          => {'3001' => 1}}])
    
    assert_equal 12+3, StatsStorage.stats_count(1001)
    list = StatsStorage.stats(1001)
    
    assert_equal true, list.include?(application_key(1001, 2001, 3001, :month,   '20100501'))
    assert_equal true, list.include?(service_key(1001, 3001, :month,  '20100501'))
      
    ## plus the 3 extras
    assert_equal true, list.include?(service_key(1001, 3001, :hour,  '2010050714'))
    assert_equal true, list.include?(application_key(1001, 2001, 3001, :hour,   '2010050714'))
    assert_equal true, list.include?(application_key(1001, 2001, 3001, :minute,   '201005071423'))
    
  end
  
  test 'empty sets' do 
    assert_equal 0, StatsStorage.stats(1001).size
    assert_equal 0, StatsStorage.stats_count(1001)
    
    assert_equal 0, StatsStorage.stats("fake_service_id").size
    assert_equal 0, StatsStorage.stats_count("fake_service_id")
  end 
  
end
