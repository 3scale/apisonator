ThreeScale::Backend.configure do |config|
  config.master_provider_key   = 'master'
  config.archiver.s3_bucket    = 's3_bucket'

  config.aws.access_key_id     = 'aws_access_key_id2'
  config.aws.secret_access_key = 'secret_access_key'

  config.redis.db              = 0
end

HoptoadNotifier.configure do |config|
  config.api_key = 'airbrake_key'
end
