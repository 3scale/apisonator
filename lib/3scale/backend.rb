require '3scale/core'
require 'aws/s3'
require 'builder'
require 'hiredis'
require 'redis'
require 'fiber'
require 'ostruct'
require 'rack/hoptoad'
require 'rack/rest_api_versioning'
require 'resque'
require 'securerandom'
require 'sinatra/base'
require 'time'
require 'yajl'
require 'yaml'
require 'zlib'

require '3scale/backend/has_set'
require '3scale/backend/storage_helpers'

require '3scale/backend/validators/base'
require '3scale/backend/validators/oauth_setting'
require '3scale/backend/validators/key'
require '3scale/backend/validators/oauth_key'
require '3scale/backend/validators/limits'
require '3scale/backend/validators/redirect_url'
require '3scale/backend/validators/referrer'
require '3scale/backend/validators/state'

require '3scale/backend/configuration'
require '3scale/backend/extensions'
require '3scale/backend/aggregator'
require '3scale/backend/allow_methods'
require '3scale/backend/application'
require '3scale/backend/archiver'
require '3scale/backend/error_storage'
require '3scale/backend/listener'
require '3scale/backend/metric'
require '3scale/backend/runner'
require '3scale/backend/logger'
require '3scale/backend/server'
require '3scale/backend/service'
require '3scale/backend/storage'
require '3scale/backend/transaction_storage'
require '3scale/backend/log_storage'
require '3scale/backend/transactor'
require '3scale/backend/usage_limit'
require '3scale/backend/user'
require '3scale/backend/cache'
require '3scale/backend/alert_storage'
require '3scale/backend/alerts'
require '3scale/backend/version'
require '3scale/backend/worker'
require '3scale/backend/errors'

module ThreeScale
  module Core
    def self.storage
      ThreeScale::Backend::Storage.instance
    end
  end

  TIME_FORMAT          = '%Y-%m-%d %H:%M:%S %z'
  PIPELINED_SLICE_SIZE = 1000
end

ThreeScale::Backend.configuration.tap do |config|
  # Add configuration sections
  config.add_section(:redis, :servers, :db, :backup_file)
  config.add_section(:archiver, :path, :s3_bucket)
  config.add_section(:hoptoad, :api_key)

  # Default config
  config.master_service_id = 1
  config.archiver.path     = '/tmp/3scale_backend/archive'

  # Load configuration from a file.
  config.load!
end

Resque.redis = ThreeScale::Backend::Storage.instance
