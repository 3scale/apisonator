# This script checks that requests are not mixed when running the listeners and
# the workers in async mode.
#
# Apisonator was not designed with Fibers in mind, so there could be bugs caused
# by having 2 fibers modifying the same singleton class during 2 concurrent
# requests, for example. This script helps to detect those kind of errors.
#
# This script creates a couple of services. Each of them has an application and
# 2 metrics, one limited and the other unlimited. First, it makes
# N_REQUESTS_TO_TEST to the listeners and checks that they return the expected
# response. Then, it starts a workers and when it finishes processing all the
# job in the queues, it checks that the stat counters contain the expected
# values.
#
# Usage:
# This script should work as is inside the dev container. If you want to run it
# on a different environment, change the constants defined below.
# Run it with:
# bundle exec ruby script/mixed_requests_test.rb

require 'net/http'
require '3scale/backend'
require 'concurrent'
require 'nokogiri'

FALCON_HOST = 'localhost'
FALCON_PORT = 3000
N_REQUESTS_TO_TEST = 1_000
CONCURRENT_REQUESTS = 64
CONFIG_FILE = '/home/ruby/.3scale_backend.config'
ETERNITY = ThreeScale::Backend::Period::Eternity.new

def write_config_file
  File.open(CONFIG_FILE, 'w+') do |f|
    f.write("ThreeScale::Backend.configure do |config|\n"\
           " config.redis.async = ENV['CONFIG_REDIS_ASYNC'].to_s == 'true' ? true : false\n"\
           "end\n")
  end
end

def delete_config_file
  File.delete(CONFIG_FILE)
end

def start_services
  system('source script/lib/functions; start_services')
  sleep(5)
end

def stop_services
  system('source script/lib/functions; stop_services')
end

def start_falcon
  system("LISTENER_WORKERS=4 CONFIG_REDIS_ASYNC=true CONFIG_FILE=#{CONFIG_FILE} bundle exec bin/3scale_backend -s falcon start -p #{FALCON_PORT} &")
  sleep(10) # Give it some time to be ready
end

def shutdown_falcon
  system("pkill -u #{Process.euid} -f \"ruby .*falcon\"")
end

def start_apisonator_worker
  system("CONFIG_REDIS_ASYNC=true CONFIG_FILE=#{CONFIG_FILE} bundle exec bin/3scale_backend_worker start")
end

def stop_apisonator_worker
  system('bin/3scale_backend_worker stop')
end

def pending_jobs
  Resque.redis.llen('queue:priority')
end

def process_all_jobs_from_queue
  start_apisonator_worker
  while pending_jobs > 0 do sleep(1) end
  stop_apisonator_worker
end

def metric_counter_for_service(service_id, metric_id, period)
  key = ThreeScale::Backend::Stats::Keys.service_usage_value_key(service_id, metric_id, period)
  ThreeScale::Backend::Storage.instance.get(key).to_i
end

def metric_counter_for_app(service_id, metric_id, app_id, period)
  key = ThreeScale::Backend::Stats::Keys.application_usage_value_key(
    service_id, app_id, metric_id, period
  )
  ThreeScale::Backend::Storage.instance.get(key).to_i
end

def is_authorized?(auth_resp)
  xml = Nokogiri::XML(auth_resp)
  xml.at('status authorized').content == 'true'
end

def authrep_req(params)
  req = ""
  req << "/transactions/authrep.xml?"
  req << "provider_key=#{params[:provider_key]}&"
  req << "service_id=#{params[:service_id]}&"
  req << "user_key=#{params[:user_key]}&"
  req << "usage%5B#{params[:metric_name]}%5D=#{params[:metric_val]}"
  req
end

def make_req(req)
  Net::HTTP.get(FALCON_HOST, req, FALCON_PORT)
end

# Creates 2 Services. They are basically the same, they have a metric that's
# unlimited and another that has a limit of 0.
def setup_3scale_services
  ## --- Service 1 ---
  service_id = '1'
  ThreeScale::Backend::Service.save!(provider_key: 'pk', id: service_id)
  ThreeScale::Backend::Application.save(
    service_id: service_id, id: '1', state: :active, plan_id: '1', plan_name: 'some_plan'
  )
  ThreeScale::Backend::Application.save_id_by_key(service_id, 'uk', '1')

  # Unlimited metric
  ThreeScale::Backend::Metric.save(service_id: service_id , id: '1', name: 'hits')

  # Limited metric
  ThreeScale::Backend::Metric.save(service_id: service_id, id: '2', name: 'limited')
  ThreeScale::Backend::UsageLimit.save(
    service_id: service_id, plan_id: '1', metric_id: '2', hour: 0
  )
  ## --- Service 1 ---


  ## --- Service 2 ---
  service_id = '2'
  ThreeScale::Backend::Service.save!(provider_key: 'pk', id: service_id)
  ThreeScale::Backend::Application.save(
    service_id: service_id, id: '1', state: :active, plan_id: '1', plan_name: 'some_plan'
  )
  ThreeScale::Backend::Application.save_id_by_key(service_id, 'uk', '1')

  # Unlimited metric
  ThreeScale::Backend::Metric.save(service_id: service_id , id: '1', name: 'hits')

  # Limited metric
  ThreeScale::Backend::Metric.save(service_id: service_id, id: '2', name: 'limited')
  ThreeScale::Backend::UsageLimit.save(
    service_id: service_id, plan_id: '1', metric_id: '2', hour: 0
  )
  ## --- Service 2 ---
end

def submit_jobs(pool, n_jobs, jobs_to_choose_from, errors)
  n_jobs.times do
    job = jobs_to_choose_from.sample
    job[:times_run] += 1

    pool.post do
      resp = make_req(job[:req])

      if is_authorized?(resp) != job[:auth]
        errors << "Got: #{is_authorized?(resp)}, wanted: #{job[:auth]}"
      end
    end
  end
end

# [Request, expected_result] pairs based on the entities set in "setup_services()"
jobs = [
  {
    req: authrep_req(
      provider_key: 'pk', service_id: '1', user_key: 'uk', metric_name: 'hits', metric_val: 1
    ),
    auth: true
  },
  {
    req: authrep_req(
      provider_key: 'pk', service_id: '1', user_key: 'uk', metric_name: 'limited', metric_val: 1
    ),
    auth: false
  },
  {
    req: authrep_req(
      provider_key: 'pk', service_id: '2', user_key: 'uk', metric_name: 'hits', metric_val: 1
    ),
    auth: true
  },
  {
    req: authrep_req(
      provider_key: 'pk', service_id: '2', user_key: 'uk', metric_name: 'limited', metric_val: 1
    ),
    auth: false
  }
]
jobs.each { |job| job[:times_run] = 0 } # Needed for checking stats counters

# Setup
write_config_file
start_services
start_falcon
setup_3scale_services

# Test listeners
errors = Concurrent::Array.new
pool = Concurrent::FixedThreadPool.new(CONCURRENT_REQUESTS)
submit_jobs(pool, N_REQUESTS_TO_TEST, jobs, errors)
pool.shutdown
pool.wait_for_termination
shutdown_falcon
listeners_error = !errors.empty?
STDERR.puts 'Unexpected responses from listeners' if listeners_error

# Test workers
process_all_jobs_from_queue
counters_error = (metric_counter_for_service('1', '1', ETERNITY) != jobs[0][:times_run]) ||
                 (metric_counter_for_app('1', '1', '1', ETERNITY) != jobs[0][:times_run]) ||
                 (metric_counter_for_service('2', '1', ETERNITY) != jobs[2][:times_run]) ||
                 (metric_counter_for_app('2', '1', '1', ETERNITY) != jobs[2][:times_run])
STDERR.puts 'Incorrect values in stats counters' if counters_error

# Clean-up
stop_services
delete_config_file

raise RuntimeError.new('Unexpected responses from listeners') if listeners_error
raise RuntimeError.new('Incorrect values in stats counters') if counters_error
