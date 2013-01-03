#puts "Using gemset: "
#system "rvm current"

require 'benchmark'
require 'fileutils'
require '3scale/backend'
require 'ruby-debug'

DEBUG = false

puts "Backend version: #{ThreeScale::Backend::VERSION}"
puts "Resque version: #{Resque::VERSION}"
puts "Redis version: #{Redis::VERSION}"

redis = ThreeScale::Backend::Storage.instance
redis.flushdb

puts "Filling seed..."
system "rake seed_user"
puts "done."



def assert_equal(a, b)
  if a!=b
    raise "Assert failed: #{a} != #{b}" if a!=b
  end
end

def add_transaction
  provider_key = "pkey"
  app_id = "app_id"
  service_id = "1001"
  transactions = {0 => {:app_id => app_id, :usage => {:hits => 4, :other => 1, :method2 => 1}, :user_id => "foo"}}
  ThreeScale::Backend::Transactor.report(provider_key,service_id,transactions)  
end


FileUtils.remove_file("/tmp/3scale_backend_workers_from_test_workers_perf.log", :force => true)

raise "Assert failed" unless redis.llen("resque:queue:main")==0
raise "Assert failed" unless redis.llen("resque:queue:priority")==0

N = 1000

puts "Starting test..."

redis_commands = Array.new

Benchmark.bm do |x|
  
  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i
  
  x.report("adding transactions: ") { N.times {add_transaction }}
  
  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i
  
  assert_equal redis.llen("resque:queue:main"), N
  assert_equal redis.llen("resque:queue:priority"), N
  
  @worker = ThreeScale::Backend::Worker.new(:one_off => true, :log_file => "/tmp/3scale_backend_workers_from_test_workers_perf.log")
  
  debugger if DEBUG
  @worker.work
  debugger if DEBUG
  @worker.work
  debugger if DEBUG
  @worker.work
  debugger if DEBUG
    
  x.report("processing priority: ") { (N-3).times { @worker.work }}

  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i


  assert_equal redis.llen("resque:queue:main"), N
  assert_equal redis.llen("resque:queue:priority"), 0
  
  assert_equal redis.get("stats/{service:1001}/cinstance:app_id/metric:8001/eternity"), (N*5).to_s
  assert_equal redis.get("stats/{service:1001}/metric:8001/eternity"), (N*5).to_s
  
  assert_equal redis.get("stats/{service:1001}/cinstance:app_id/metric:8002/eternity"), N.to_s
  assert_equal redis.get("stats/{service:1001}/metric:8002/eternity"), N.to_s
  
  assert_equal redis.get("stats/{service:1001}/cinstance:app_id/metric:80012/eternity"), N.to_s
  assert_equal redis.get("stats/{service:1001}/metric:80012/eternity"), N.to_s

  assert_equal redis.get("stats/{service:1001}/uinstance:foo/metric:8001/eternity"), (N*5).to_s
  assert_equal redis.get("stats/{service:1001}/uinstance:foo/metric:8002/eternity"), N.to_s  
  assert_equal redis.get("stats/{service:1001}/uinstance:foo/metric:80012/eternity"), N.to_s

  x.report("processing main:     ") { (N).times { @worker.work  }}

  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i

  assert_equal redis.llen("resque:queue:main"), 0
  assert_equal redis.llen("resque:queue:priority"), 0
  
  assert_equal redis.get("stats/{service:1001}/cinstance:app_id/metric:8001/eternity"), (N*5).to_s
  assert_equal redis.get("stats/{service:1001}/metric:8001/eternity"), (N*5).to_s
  
  assert_equal redis.get("stats/{service:1001}/cinstance:app_id/metric:8002/eternity"), N.to_s
  assert_equal redis.get("stats/{service:1001}/metric:8002/eternity"), N.to_s
  
  assert_equal redis.get("stats/{service:1001}/cinstance:app_id/metric:80012/eternity"), N.to_s
  assert_equal redis.get("stats/{service:1001}/metric:80012/eternity"), N.to_s
  
  assert_equal redis.get("stats/{service:1001}/uinstance:foo/metric:8001/eternity"), (N*5).to_s
  assert_equal redis.get("stats/{service:1001}/uinstance:foo/metric:8002/eternity"), N.to_s  
  assert_equal redis.get("stats/{service:1001}/uinstance:foo/metric:80012/eternity"), N.to_s

  system "wc -l /tmp/3scale_backend_workers_from_test_workers_perf.log > /tmp/temp_wc_l.tmp"
  num_entries_log = File.new("/tmp/temp_wc_l.tmp","r").read.to_i
  assert_equal (N*2)+1, num_entries_log
  
  puts "\nRedis commands:"
  i=1
  while i < redis_commands.size do
    puts "#{(redis_commands[i] - redis_commands[i-1]) / N.to_f} redis commands per request"
    i=i+1
  end
  
end  

