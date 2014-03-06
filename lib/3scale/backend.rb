require '3scale/core'
require 'aws/s3'
require 'builder'
require 'hiredis'
require 'redis'
require 'fiber'
require 'ostruct'
require 'airbrake'
require 'rack/rest_api_versioning'
require 'resque'
require 'securerandom'
require 'sinatra/base'
require 'time'
require 'yajl'
require 'yaml'
require 'zlib'
require 'rest-client'
require 'digest/md5'
require 'logger'

require '3scale/backend/has_set'
require '3scale/backend/storage_helpers'

require '3scale/backend/rack_exception_catcher'
require '3scale/backend/configuration'
require '3scale/backend/extensions'
require '3scale/backend/allow_methods'
require '3scale/backend/oauth_access_token_storage'
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
require '3scale/backend/log_request_storage'
require '3scale/backend/aggregator'
require '3scale/backend/storage_mongo'
require '3scale/backend/transactor'
require '3scale/backend/usage_limit'
require '3scale/backend/user'
require '3scale/backend/cache'
require '3scale/backend/alert_storage'
require '3scale/backend/alerts'
require '3scale/backend/event_storage'
require '3scale/backend/version'
require '3scale/backend/worker'
require '3scale/backend/errors'
require '3scale/backend/memoizer'

module ThreeScale
  module Core
    def self.storage
      ThreeScale::Backend::Storage.instance
    end
  end

  TIME_FORMAT          = '%Y-%m-%d %H:%M:%S %z'
  PIPELINED_SLICE_SIZE = 400
  REPORT_DEADLINE      = 24*3600
end

ThreeScale::Backend.configuration.tap do |config|
  # Add configuration sections
  config.add_section(:redis, :servers, :db, :backup_file)
  config.add_section(:archiver, :path, :s3_bucket)
  config.add_section(:hoptoad, :api_key)
  config.add_section(:stats, :bucket_size)
  config.add_section(:mongo, :servers, :db, :db_options)

  # Default config
  config.master_service_id = 1
  config.archiver.path     = '/tmp/3scale_backend/archive'

  ## this means that there will be a NotifyJob for every X notifications (this is 
  ## the call to master)
  config.notification_batch = 10000

  # Load configuration from a file.
  config.load!
end

Resque.redis = ThreeScale::Backend::Storage.instance
