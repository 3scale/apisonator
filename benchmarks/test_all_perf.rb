require '3scale/backend'
require 'benchmark'
require 'fileutils'
require 'nokogiri'
require 'ruby-debug'

N = 1000

puts "Backend version: #{ThreeScale::Backend::VERSION}"
puts "Resque version: #{Resque::VERSION}"
puts "Redis version: #{Redis::VERSION}"

redis = ThreeScale::Backend::Storage.instance
redis.flushdb

puts "Filling seed..."
system "rake seed_user"
puts "done."

## DATA
@provider_key = "pkey"
@app_id = "app_id"
@service_id = "1001"
@user_id = "foo"
@usage = {"hits" => 4, "other" => 1, "method2" => 1}

def assert_equal(a, b)
  raise "Assert failed: #{a} != #{b}" if a!=b
end

def add_transaction
  transactions = {0 => {:app_id => @app_id, :usage => @usage.symbolize_keys, :user_id => @user_id}}
  ThreeScale::Backend::Transactor.report(@provider_key,@service_id,transactions)  
end

def do_authrep
  params = {}
  params[:usage] = @usage
  params[:user_id] = @user_id
  params[:app_id] = @app_id    
  ThreeScale::Backend::Transactor.authrep(@provider_key, params)
end

def do_authorize
  params = {}
  params[:usage] = @usage
  params[:user_id] = @user_id
  params[:app_id] = @app_id  
  ThreeScale::Backend::Transactor.authorize(@provider_key, params)
end


FileUtils.remove_file("/tmp/3scale_backend_workers_from_test_workers_perf.log", :force => true)

raise "Assert failed" unless redis.llen("resque:queue:main")==0
raise "Assert failed" unless redis.llen("resque:queue:priority")==0

puts "Starting test..."

redis_commands = Array.new
labels = [""]

Benchmark.bm do |x|
  
  labels << "adding transactions: "
  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i  
  x.report("adding transactions: ") { N.times {add_transaction }}
    
  assert_equal redis.llen("resque:queue:main"), N
  assert_equal redis.llen("resque:queue:priority"), N
  
  @worker = ThreeScale::Backend::Worker.new(:one_off => true, :log_file => "/tmp/3scale_backend_workers_from_test_workers_perf.log")
  
  labels << "processing priority: " 
  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i
  x.report("processing priority: ") { (N).times { @worker.work }}

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

  labels << "processing main: "
  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i
  x.report("processing main:     ") { (N).times { @worker.work  }}

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
  
  labels << "do authrep with caching: "
  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i
  x.report("do authrep with caching: ") { (N-1).times {do_authrep }}
  
  response = do_authrep  
  doc = Nokogiri::XML(response[1])
  assert_equal 'true', doc.at('status:root authorized').content
  
  labels << "do authorize with caching: "
  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i
  x.report("do authorize with caching: ") { (N-1).times {do_authorize }}
  
  response = do_authorize
  doc = Nokogiri::XML(response[1])
  assert_equal 'true', doc.at('status:root authorized').content
    
  ThreeScale::Backend::Transactor.caching_disable
  
  labels << "do authrep without caching: "
  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i
  x.report("do authrep without caching: ") { (N-1).times {do_authrep }}
  
  response = do_authrep
  doc = Nokogiri::XML(response.first.to_xml)
  assert_equal 'true', doc.at('status:root authorized').content
  
  ThreeScale::Backend::Transactor.caching_disable
  
  labels << "do authorize without caching: "
  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i
  x.report("do authorize without caching: ") { (N-1).times {do_authorize }}
  
  response = do_authorize
  doc = Nokogiri::XML(response.first.to_xml)
  assert_equal 'true', doc.at('status:root authorized').content
  
  system "wc -l /tmp/3scale_backend_workers_from_test_workers_perf.log > /tmp/temp_wc_l.tmp"
  num_entries_log = File.new("/tmp/temp_wc_l.tmp","r").read.to_i
  assert_equal (N*2)+1, num_entries_log
  
  redis_commands << ThreeScale::Backend::Storage.instance.info["total_commands_processed"].to_i
  puts "\nRedis commands:"
  i=1
  while i < redis_commands.size do
    puts "#{labels[i]} #{(redis_commands[i] - redis_commands[i-1]) / N.to_f} redis commands per request"
    i=i+1
  end
  
  ThreeScale::Backend::Transactor.caching_enable
  
  
end  

