
#puts "Using gemset: "
#system "rvm current"

require 'benchmark'
require '3scale/backend'

puts "Backend version: #{ThreeScale::Backend::VERSION}"
puts "Resque version: #{Resque::VERSION}"
puts "Redis version: #{Redis::VERSION}"

redis = ThreeScale::Backend::Storage.instance
redis.flushdb

puts "Filling seed..."
system "rake seed"

def assert_equal(a, b)
  if a!=b
    raise "Assert failed: #{a} != #{b}" if a!=b
  end
end

def add_transaction
  provider_key = "pkey"
  app_id = "app_id"
  service_id = "1001"
  transactions = {0 => {:app_id => app_id, :usage => {:hits => 5}}}
  ThreeScale::Backend::Transactor.report(provider_key,service_id,transactions)  
end

def process_transaction
  
  ThreeScale::Backend::Worker.work(:one_off => true)
  
end


#raise "Assert failed" if redis.llen("resque:queue:main")==0
#raise "Assert failed" if redis.llen("resque:queue:priority")==0

N = 10000

puts "Starting test..."

Benchmark.bm do |x|

  x.report("adding transactions: ") { N.times {add_transaction }}
  
  assert_equal redis.llen("resque:queue:main"), N
  assert_equal redis.llen("resque:queue:priority"), N
  
  @worker = ThreeScale::Backend::Worker.new(:one_off => true)
  
  x.report("processing priority: ") { (N).times { @worker.work }}

  assert_equal redis.llen("resque:queue:main"), N
  assert_equal redis.llen("resque:queue:priority"), 0
  
  assert_equal redis.get("stats/{service:1001}/cinstance:app_id/metric:8001/eternity"), (N*5).to_s
  assert_equal redis.get("stats/{service:1001}/metric:8001/eternity"), (N*5).to_s
  
  x.report("processing main:     ") { (N).times { @worker.work  }}

  assert_equal redis.llen("resque:queue:main"), 0
  assert_equal redis.llen("resque:queue:priority"), 0
  
  assert_equal redis.get("stats/{service:1001}/cinstance:app_id/metric:8001/eternity"), (N*5).to_s
  assert_equal redis.get("stats/{service:1001}/metric:8001/eternity"), (N*5).to_s
  
    
end  