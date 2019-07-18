#!/usr/bin/env ruby

require 'securerandom'
require '3scale/core'
require 'uri'

endpoint = ENV.fetch('BACKEND_ENDPOINT')

uri = case endpoint
        when URI::regexp(%w(http https)) then URI(endpoint)
        else URI("http://#{endpoint}")
      end

uri.path = '/internal/'

puts "Backend endpoint: #{uri}"
puts

ThreeScale::Core.url = uri
ThreeScale::Core.username = ENV['CONFIG_INTERNAL_API_USER']
ThreeScale::Core.password = ENV['CONFIG_INTERNAL_API_PASSWORD']

service_id = ENV.fetch('SERVICE_ID', SecureRandom.hex(4))
provider_key = ENV.fetch('PROVIDER_KEY', SecureRandom.uuid)
application_id = ENV.fetch('APPLICATION_ID', SecureRandom.hex(4))
plan_id = ENV.fetch('PLAN_ID', SecureRandom.hex(4))
user_key = ENV.fetch('USER_KEY', SecureRandom.hex(8))
metric_id = ENV.fetch('METRIC_ID', SecureRandom.hex(4))
metric_name = ENV.fetch('METRIC_NAME', SecureRandom.hex(4))

ThreeScale::Core::Service.save!(id: service_id, provider_key: provider_key)

ThreeScale::Core::Application.save(service_id: service_id, id: application_id,
                                   state: :active,
                                   plan_id: plan_id, plan_name: 'plan name')

ThreeScale::Core::Application.save_id_by_key(service_id, user_key, application_id)

ThreeScale::Core::Metric.save(service_id: service_id, id: metric_id, name: metric_name)

ThreeScale::Core::UsageLimit.save(service_id: service_id, plan_id: plan_id,
                                  metric_id: metric_id, eternity: 1)

query = URI.encode_www_form(provider_key: provider_key, service_id: service_id,
                            user_key: user_key, "usage[#{metric_name}]" => '1')

authrep = uri.merge("/transactions/authrep.xml?#{query}")

puts
puts "GET #{authrep}"
success = Net::HTTP.get(authrep)

unless success.match('<authorized>true</authorized>')
  raise "Failed to authorize. Response: #{success}"
end
puts "Response: #{success}"


puts
puts "GET #{authrep}"
failure = Net::HTTP.get(authrep)

unless failure.match('<authorized>false</authorized><reason>usage limits are exceeded</reason>')
  raise "Expected to fail authorization. Response: #{failure}"
end

puts "Response: #{failure}"

puts
puts 'Test completed successfully'
