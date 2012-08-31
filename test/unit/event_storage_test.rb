require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class EventStorageTest < Test::Unit::TestCase
  include TestHelpers::Sequences
  include StorageHelpers
 
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    
    @service_id     = next_id
    @application_id = next_id
    @metric_id      = next_id
  end

  test 'test addition and retrieval' do
    
    timestamp = Time.now.utc
    
    alerts = []
    10.times.each do |i|
      alerts << {:id => next_id, :service_id => i, :application_id => "app1", :utilization => 90, 
        :max_utilization => 90.0, :limit => "metric X: 90 of 100", :timestamp => timestamp}
    end
    
    assert_equal 0, EventStorage.size()
    assert_equal 0, EventStorage.list().size
    
    EventStorage.store(:alert, alerts[0])
    EventStorage.store(:alert, alerts[1])
    
    list = EventStorage.list()
    saved_id = list.last[:id]
    
    
    EventStorage.store(:alert, alerts[2])
    
    assert_equal 3, EventStorage.size()
    assert_equal 3, EventStorage.list().size
    
    list = EventStorage.list()
    
    list.size.times.each do |i|
      assert_equal encode(alerts[i]), encode(list[i][:object])
      assert_equal "alert", list[i][:type]
    end
    
    ## a repeated gets counted
    EventStorage.store(:alert, alerts[0])    
    assert_equal 4, EventStorage.size()
    assert_equal 4, EventStorage.list().size
    
    ## removing nothing
    assert_equal 0, EventStorage.delete(-1)
    
    ## removing the first two
    assert_equal 2, EventStorage.delete(saved_id)
    
    list = EventStorage.list()
    assert_equal 2, EventStorage.size()
    assert_equal 2, EventStorage.list().size
     
    list.each_with_index do |item, i|
      assert_equal saved_id + 1 + i, item[:id]
    end 
     
    ## removing all
    assert_equal 2, EventStorage.delete(99999999)
    list = EventStorage.list()
    assert_equal 0, EventStorage.size()
    assert_equal 0, EventStorage.list().size
     
    ## removing when empty
    assert_equal 0, EventStorage.delete(99999999) 
    
  end
  
  
  test 'type is defined' do
    
    EventStorage.store(:alert, {})
    EventStorage.store(:first_traffic, {})
    
    assert_raise Exception do 
      EventStorage.store(:foo, {})
    end
    
  end
  
  test 'ping behavior' do
    
  end
  
  
  
end
