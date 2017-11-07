#!/usr/bin/env ruby

## This script reads a list of Redis keys and classifies them. It outputs how
## many of them contain stats, service attributes, application attributes,
## alerts, etc.
## To get a list of Redis keys from an rdb file, you can use rdbtools
## (https://github.com/sripathikrishnan/redis-rdb-tools):
## rdb --command justkeys dump.rdb
##
## Usage: redis_keys_distr dump_file
##

KEY_TYPES =
    { alerts_allowed_set_for_service: /alerts\/service_id:.*\/allowed_set/,
      alerts_discrete_period_day: /alerts\/service_id:.*\/app_id:.*\/.*\/(?!(already_notified|current_max))/,
      alerts_discrete_already_notified: /alerts\/service_id:.*\/app_id:.*\/.*\/already_notified/,
      alerts_period_hour_current_max: /alerts\/service_id:.*\/app_id:.*\/.*\/current_max/,
      alerts_last_time_period: /alerts\/service_id:.*\/app_id:.*\/last_time_period/,
      alerts_stats_utilization: /alerts\/service_id:.*\/app_id:.*\/stats_utilization/,
      alerts_current_id: /alerts\/current_id/,
      app_events_daily_traffic: /daily_traffic\/service:.*\/cinstance:.*\/.*/,
      app_attrs: /application\/service_id:.*\/id:.*\/.*/,
      app_id_by_key: /application\/service_id:.*\/key:.*\/id/,
      apps_of_service: /service_id:.*\/applications/,
      dist_locks: /.*:lock/,
      errors: /errors\/service_id:.*/,
      events_queue: /events\/queue/,
      events_ping: /events\/ping/,
      events_id: /events\/id/,
      metrics_attrs: /metric\/service_id:.*\/id:.*\/.*/,
      metrics_id_from_name: /metric\/service_id:.*\/name:.*\/id/,
      metrics_of_service: /metrics\/service_id:.*\/ids/,
      notify_job_batch: /notify\/aggregator\/batch/,
      oauth_token: /oauth_access_tokens\/service:.*\/(?!app:).*(?<!\/)\b/,
      oauth_token_of_app: /oauth_access_tokens\/service:.*\/app:.*/,
      service_token: /service_token\/token:.*\/service_id:.*/,
      service_attrs: /service\/id:.*\/.*/,
      service_attrs_by_provider_key: /service\/provider_key:.*\/.*/,
      services_set: /services_set/,
      provider_keys_set: /provider_keys_set/,
      stats_service_cinstances: /stats\/{service:.*}\/cinstances/, #used for first traffic
      stats_service_metric: /stats\/{service:.*}\/metric:.*/,
      stats_app_metric: /stats\/{service:.*}\/cinstance:.*\/metric:.*/,
      stats_user_metric: /stats\/{service:.*}\/uinstance:.*\/metric:.*/,
      stats_service_resp_code: /stats\/{service:.*}\/response_code:.*/,
      stats_app_resp_code: /stats\/{service:.*}\/cinstance:.*\/response_code:.*/,
      stats_user_resp_code: /stats\/{service:.*}\/uinstance:.*\/response_code:.*/,
      transactions: /transactions\/service_id:.*/,
      usage_limits: /usage_limit\/service_id:.*\/plan_id:.*\/metric_id:.*\/.*/,
      user: /service:.*\/user:.*/
    }.freeze

def key_type(line)
  type = KEY_TYPES.find { |_type, regex| line =~ regex }
  type ? type.first : nil
end

def print_results(total_keys, unknown_keys, counters)
  puts "total keys: #{total_keys}"
  puts "unknown keys: #{unknown_keys}"
  counters.each do |type, value|
    perc = 100*(value/total_keys.to_f).round(2)
    puts "#{type} keys: #{value} (#{perc} %)"
  end
end

abort 'usage: redis_keys_distr dump_file' unless ARGV[0]

total_keys = 0
unknown_keys = 0

key_type_counters = {}
KEY_TYPES.keys.each { |type| key_type_counters[type] = 0 }

File.open(ARGV[0], 'r').each_line do |line|
  type = key_type(line.chomp)
  type ? key_type_counters[type] += 1 : unknown_keys += 1
  total_keys += 1
end

print_results(total_keys, unknown_keys, key_type_counters)
