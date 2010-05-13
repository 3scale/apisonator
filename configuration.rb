ThreeScale::Backend.configure do |config|
  config.master_provider_key = 'master'

  config.archiver.path         = '/tmp/transactions'
  config.archiver.s3_bucket    = 's3_bucket'

  config.aws.access_key_id     = 'aws_access_key_id2'
  config.aws.secret_access_key = 'secret_access_key'

  config.redis.db              = 0

  case ENV['RACK_ENV']
  when 'development'
    config.archiver.s3_bucket    = 's3_bucket'
    config.redis.db              = 1
  when 'test'
    config.archiver.s3_bucket    = 's3_bucket'
    
    # so I don't accidentally access s3
    config.aws.access_key_id     = 'test_access_key_id'
    config.aws.secret_access_key = 'test_secret_access_key'
    
    config.redis.db              = 2
  end
end

HoptoadNotifier.configure do |config|
  config.api_key = 'airbrake_key'
end
