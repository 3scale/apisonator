require '3scale/backend'

ThreeScale::Backend.configure do |config|
  config.master_service_id = 1
  config.notification_batch = 5
  config.redis.async = ENV['CONFIG_REDIS_ASYNC'].to_s == 'true' ? true : false
end
