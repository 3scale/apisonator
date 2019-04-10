require '3scale/backend'

ThreeScale::Backend.configure do |config|
  config.stats.bucket_size  = 5
  config.notification_batch = 5
  config.redshift.host = 'localhost'
  config.redshift.port = 5432
  config.redshift.dbname = 'test'
  config.redshift.user = 'postgres'
  config.redis.async = ENV['CONFIG_REDIS_ASYNC'].to_s == 'true' ? true : false
end
