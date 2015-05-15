require 'builder'
require 'hiredis'
require 'redis'
require 'airbrake'
require 'resque'
require 'securerandom'
require 'sinatra/base'
require 'time'
require 'yajl'
require 'yaml'
require 'digest/md5'

require '3scale/backend/logger'
require '3scale/backend/has_set'
require '3scale/backend/storage_helpers'
require '3scale/backend/storage_key_helpers'
require '3scale/backend/storable'
require '3scale/backend/helpers'

require_relative '../../app/api/api'

require '3scale/backend/rack_exception_catcher'
require '3scale/backend/configuration'
require '3scale/backend/extensions'
require '3scale/backend/background_job'
require '3scale/backend/allow_methods'
require '3scale/backend/oauth_access_token_storage'
require '3scale/backend/memoizer'
require '3scale/backend/application'
require '3scale/backend/error_storage'
require '3scale/backend/listener'
require '3scale/backend/metric'
require '3scale/backend/runner'
require '3scale/backend/server'
require '3scale/backend/service'
require '3scale/backend/storage'
require '3scale/backend/queue_storage'
require '3scale/backend/transaction_storage'
require '3scale/backend/log_request_storage'
require '3scale/backend/log_request_cubert_storage'
require '3scale/backend/stats/aggregator'
require '3scale/backend/transactor'
require '3scale/backend/usage_limit'
require '3scale/backend/user'
require '3scale/backend/cache'
require '3scale/backend/alerts'
require '3scale/backend/event_storage'
require '3scale/backend/worker'
require '3scale/backend/errors'

module ThreeScale
  TIME_FORMAT          = '%Y-%m-%d %H:%M:%S %z'
  PIPELINED_SLICE_SIZE = 400

  module Backend
    def self.environment
      ENV['RACK_ENV'] || 'development'
    end

    def self.production?
      environment == 'production'
    end

    def self.development?
      environment == 'development'
    end

    def self.test?
      environment == 'test'
    end

    configuration.tap do |config|
      # Add configuration sections
      config.add_section(:queues, :master_name, :sentinels)
      config.add_section(:redis, :proxy, :nodes, :backup_file)
      config.add_section(:hoptoad, :api_key)
      config.add_section(:stats, :bucket_size)
      config.add_section(:influxdb, :hosts, :database,
                         :username, :password, :retry,
                         :write_timeout, :read_timeout
                        )
      config.add_section(:cubert, :host)

      # Default config
      config.master_service_id  = 1

      ## this means that there will be a NotifyJob for every X notifications (this is
      ## the call to master)
      config.notification_batch = 10000

      # Load configuration from a file.
      config.load!
    end

    # We should think about chaing it to something more general.
    @logger = Logger.new "#{(development? || test?) ? ENV['HOME'] :
      configuration.log_path}/backend_logger.log", 10

    def self.logger
      @logger
    end
  end
end

Airbrake.configure do |config|
  config.api_key = ThreeScale::Backend.configuration.hoptoad.api_key
  config.rescue_rake_exceptions = true
  config.environment_name = ThreeScale::Backend.environment
end

Resque.redis = ThreeScale::Backend::QueueStorage.connection(
  ThreeScale::Backend.environment,
  ThreeScale::Backend.configuration,
)
