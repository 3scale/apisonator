require '3scale/backend'

ThreeScale::Backend.configure do |config|
  config.redis.nodes = [
    "127.0.0.1:7379",
    "127.0.0.1:7380",
  ]
  config.stats.bucket_size  = 5
  config.notification_batch = 5
  config.redshift.host = 'localhost'
  config.redshift.port = 5432
  config.redshift.dbname = 'test'
  config.redshift.user = 'postgres'
end
