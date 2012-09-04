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
    assert_equal 0, EventStorage.delete_range("foo")
    
    ## removing nothing
    assert_equal 0, EventStorage.delete_range(nil)
      
    
    ## removing nothing
    assert_equal 0, EventStorage.delete_range(-1)
    
    ## removing the first two
    assert_equal 2, EventStorage.delete_range(saved_id)
    
    list = EventStorage.list()
    assert_equal 2, EventStorage.size()
    assert_equal 2, EventStorage.list().size
     
    list.each_with_index do |item, i|
      assert_equal saved_id + 1 + i, item[:id]
    end 
     
    ## removing all
    assert_equal 2, EventStorage.delete_range(99999999)
    list = EventStorage.list()
    assert_equal 0, EventStorage.size()
    assert_equal 0, EventStorage.list().size
     
    ## removing when empty
    assert_equal 0, EventStorage.delete_range(99999999) 
    
  end
  
  test 'delete by id' do 
    
     timestamp = Time.now.utc

      alerts = []
      10.times.each do |i|
        alerts << {:id => next_id, :service_id => i, :application_id => "app1", :utilization => 90, 
          :max_utilization => 90.0, :limit => "metric X: 90 of 100", :timestamp => timestamp}
      end

      10.times do |i|
        EventStorage.store(:alert, alerts[0])
      end

      EventStorage.store(:first_traffic, {:service_id => 11, 
                                          :application_id => "app1", 
                                          :timestamp => timestamp})
                                                                            
      list = EventStorage.list()
      assert_equal 11, EventStorage.size()
      assert_equal 11, EventStorage.list().size
      
      item = list[list.size-2]
          
      assert_equal 1, EventStorage.delete(item[:id])
      assert_equal 10, EventStorage.size()
      
      ## no longer exists
      list = EventStorage.list()
      list.each do |item2|
        assert_not_equal item[:id], item2[:id]
      end  
      
      ## nothing happens when removing twice
      assert_equal 0, EventStorage.delete(item[:id])
      assert_equal 10, EventStorage.size()
  
      
  
      ## bad cases
      assert_equal 0, EventStorage.delete(nil)
      assert_equal 10, EventStorage.size()  
      
      assert_equal 0, EventStorage.delete(-1)
      assert_equal 10, EventStorage.size()
      
      assert_equal 0, EventStorage.delete("foo")
      assert_equal 10, EventStorage.size()
  
      ## bad cases
      assert_equal 0, EventStorage.delete_range(nil)
      assert_equal 10, EventStorage.size()  
      
      assert_equal 0, EventStorage.delete_range(-1)
      assert_equal 10, EventStorage.size()
      
      assert_equal 0, EventStorage.delete_range("foo")
      assert_equal 10, EventStorage.size()    
  
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
