# load the bundler shim
require_relative 'bundler_shim'

require 'builder'
require 'hiredis'
require 'redis'
require 'resque'
require 'securerandom'
require 'sinatra/base'
require 'time'
require 'yajl'
require 'yaml'
require 'digest/md5'

# Require here the classes needed for configuring Backend
require '3scale/backend/configuration'
require '3scale/backend/configurable'
require '3scale/backend/logger'

require '3scale/backend/constants'
require '3scale/backend/environment'

module ThreeScale
  module Backend
    def self.configure_airbrake
      if configuration.saas
        require 'airbrake'
        Airbrake.configure do |config|
          config.api_key = configuration.hoptoad.api_key
          config.environment_name = environment
        end
      end
    end
    private_class_method :configure_airbrake

    def self.enable_logging
      Logging.enable! on: self.singleton_class,
                      with: [logs_file, 10] do |logger|
        logger.define_singleton_method(:notify, logger_notify_proc(logger))
      end
    end
    private_class_method :enable_logging

    def self.logs_file
      # We should think about changing it to something more general.
      dir = configuration.log_path

      if !dir.nil? && !dir.empty?
        if File.stat(dir).ftype == 'directory'.freeze
          "#{dir}/backend_logger.log"
        else
          dir
        end
      elsif development? || test?
        ENV['LOG_PATH'] || '/dev/null'.freeze
      else # production without configuration.log_path specified
        STDOUT
      end
    end
    private_class_method :logs_file

    def self.logger_notify_proc(logger)
      if airbrake_enabled?
        Airbrake.method(:notify).to_proc
      else
        logger.method(:error).to_proc
      end
    end
    private_class_method :logger_notify_proc

    def self.airbrake_enabled?
      defined?(Airbrake) && Airbrake.configuration.api_key
    end
    private_class_method :airbrake_enabled?

    configure_airbrake
    enable_logging
  end
end

# Some classes depend on the configuration above. For example, some classes
# need to know the value of config.saas when they are required. That is why it
# is better to put these requires here instead of putting them at the beginning
# of the file even if it can seem a bit unusual at first.
require '3scale/backend/util'
require '3scale/backend/manifest'
require '3scale/backend/logger/middleware'
require '3scale/backend/period'
require '3scale/backend/storage_helpers'
require '3scale/backend/storage_key_helpers'
require '3scale/backend/storable'
require '3scale/backend/usage'
require '3scale/backend/rack_exception_catcher'
require '3scale/backend/extensions'
require '3scale/backend/background_job'
require '3scale/backend/storage'
require '3scale/backend/oauth'
require '3scale/backend/memoizer'
require '3scale/backend/application'
require '3scale/backend/error_storage'
require '3scale/backend/metric'
require '3scale/backend/service'
require '3scale/backend/queue_storage'
require '3scale/backend/transaction_storage'
require '3scale/backend/errors'
require '3scale/backend/stats/aggregator'
require '3scale/backend/usage_limit'
require '3scale/backend/user'
require '3scale/backend/alerts'
require '3scale/backend/event_storage'
require '3scale/backend/worker'
require '3scale/backend/service_token'
require '3scale/backend/distributed_lock'
require '3scale/backend/failed_jobs_scheduler'
require '3scale/backend/transactor'
require '3scale/backend/saas'
require '3scale/backend/listener'

Resque.redis = ThreeScale::Backend::QueueStorage.connection(
  ThreeScale::Backend.environment,
  ThreeScale::Backend.configuration,
)
