require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StorageHelpersTest < Test::Unit::TestCase
  include Backend::Aggregator
  include TestHelpers::Sequences
  
  def setup
  
    @service_id = next_id
    @application = Application.save(:service_id => @service_id, :id => next_id, :state => :active)
    @metric = Metric.save(:service_id => @service_id, :id => next_id, :name => 'hits')
    
  end

  def basic_working_of_redis_key_2_cassandra_key_and_redis_key_2_cassandra_key_inverted
  
    
    time = Time.utc(2010, 10, 30, 20, 00, 30)
    
    Timecop.freeze(time) do
    
      redis_key = usage_value_key(@application, @metric.id, :year, time)
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/year:20100101", redis_key
    
      rk, ck = redis_key_2_cassandra_key(redis_key)      
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/year:2010", rk
      assert_equal "2010", ck

      rk, ck = redis_key_2_cassandra_key_inverted(redis_key)
      assert_equal nil, rk
      assert_equal nil, ck

      redis_key = usage_value_key(@application, @metric.id, :month, time)      
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/month:20101001", redis_key
    
      rk, ck = redis_key_2_cassandra_key(redis_key)      
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/month:2010", rk
      assert_equal "201010", ck

      rk, ck = redis_key_2_cassandra_key_inverted(redis_key)
      assert_equal nil, rk
      assert_equal nil, ck

      redis_key = usage_value_key(@application, @metric.id, :week, time)      
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/week:20101025", redis_key
    
      rk, ck = redis_key_2_cassandra_key(redis_key)      
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/week:2010", rk
      assert_equal "20101025", ck

      rk, ck = redis_key_2_cassandra_key_inverted(redis_key)
      assert_equal nil, rk
      assert_equal nil, ck

      redis_key = usage_value_key(@application, @metric.id, :day, time)      
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/day:20101030", redis_key
    
      rk, ck = redis_key_2_cassandra_key(redis_key)      
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/day:2010", rk
      assert_equal "20101030", ck

      rk, ck = redis_key_2_cassandra_key_inverted(redis_key)
      assert_equal nil, rk
      assert_equal nil, ck
      
      
      redis_key = usage_value_key(@application, @metric.id, :hour, time)      
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/hour:201010302", redis_key
    
      rk, ck = redis_key_2_cassandra_key(redis_key)      
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/hour:2010", rk
      assert_equal "2010103020", ck

      rk, ck = redis_key_2_cassandra_key_inverted(redis_key)
      
      assert_equal "2010103020", rk
      assert_equal "{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}", ck

      redis_key = usage_value_key(@application, @metric.id, :minute, time)      
      ## note that since minute is :00 it's the same as the hours 
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/minute:201010302", redis_key
    
      rk, ck = redis_key_2_cassandra_key(redis_key)      
      assert_equal "stats/{service:#{@service_id}}/cinstance:#{@application.id}/metric:#{@metric.id}/minute:2010", rk
      assert_equal "201010302000", ck

      rk, ck = redis_key_2_cassandra_key_inverted(redis_key)
      assert_equal nil, rk
      assert_equal nil, ck      
      
    end


  end
  
  
end
