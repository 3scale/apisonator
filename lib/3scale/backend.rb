# Setup bundler if present before anything else.
#
# We are not guaranteed to be running in a Bundler context, so make sure we get
# the correct environment set up to require the correct code.
begin
  require 'bundler/setup'
  if !Bundler::SharedHelpers.in_bundle?
    # Gemfile not found, try with relative Gemfile from us
    require 'pathname'
    ENV['BUNDLE_GEMFILE'] = File.expand_path(File.join('..', '..', '..', 'Gemfile'),
                                             Pathname.new(__FILE__).realpath)
    require 'bundler'
    Bundler.setup
  end
rescue LoadError, Bundler::BundlerError => e
  STDERR.puts "CRITICAL: Bundler could not be loaded properly - #{e.message}"
end

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

require '3scale/backend/util'
require '3scale/backend/manifest'
require '3scale/backend/logger'
require '3scale/backend/logger/middleware'
require '3scale/backend/has_set'
require '3scale/backend/storage_helpers'
require '3scale/backend/storage_key_helpers'
require '3scale/backend/storable'
require '3scale/backend/usage'

require '3scale/backend/rack_exception_catcher'
require '3scale/backend/configuration'
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

    configuration.tap do |config|
      # To distinguish between SaaS and on-premises mode.
      config.saas = true

      config.request_loggers = [:text]

      # Add configuration sections
      config.add_section(:queues, :master_name, :sentinels,
                         :connect_timeout, :read_timeout, :write_timeout)
      config.add_section(:redis, :proxy, :nodes,
                         :connect_timeout, :read_timeout, :write_timeout)
      config.add_section(:hoptoad, :api_key)
      config.add_section(:stats, :bucket_size)
      config.add_section(:cubert, :host)
      config.add_section(:redshift, :host, :port, :dbname, :user, :password)
      config.add_section(:statsd, :host, :port)
      config.add_section(:internal_api, :user, :password)

      # Default config
      config.master_service_id  = 1

      ## this means that there will be a NotifyJob for every X notifications (this is
      ## the call to master)
      config.notification_batch = 10000

      # This setting controls whether the listener can create event buckets in
      # Redis. We do not want all the listeners creating buckets yet, as we do
      # not know exactly the rate at which we can send events to Kinesis
      # without problems.
      # By default, we will allow creating buckets in any environment that is
      # not 'production'.
      # Notice that in order to create buckets, you also need to execute this
      # rake task: stats:buckets:enable
      config.can_create_event_buckets = !production?

      # Load configuration from a file.
      config.load!

      # can_create_event_buckets is just for our SaaS analytics system.
      # If SaaS has been set to false, we need to disable buckets too.
      config.can_create_event_buckets = false unless config.saas
    end

    configure_airbrake
    enable_logging
  end
end

Resque.redis = ThreeScale::Backend::QueueStorage.connection(
  ThreeScale::Backend.environment,
  ThreeScale::Backend.configuration,
)

# Need to be required after the config params are set
require '3scale/backend/transactor'
require '3scale/backend/saas'
require '3scale/backend/listener'
