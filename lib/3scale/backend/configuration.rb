require '3scale/dotenv'
require '3scale/backend/configuration/loader'
require '3scale/backend/environment'
require '3scale/backend/configurable'
require '3scale/backend/errors'

module ThreeScale
  module Backend
    class << self
      attr_accessor :configuration

      def configure
        yield configuration
      end

      private

      def parse_int(value, default)
        case value
        when "", nil, false then default
        else Integer(value)
        end
      end
    end

    NOTIFICATION_BATCH_DEFAULT = 10000
    private_constant :NOTIFICATION_BATCH_DEFAULT

    CONFIG_MASTER_METRICS_TRANSACTIONS_DEFAULT = "transactions".freeze
    private_constant :CONFIG_MASTER_METRICS_TRANSACTIONS_DEFAULT
    CONFIG_MASTER_METRICS_TRANSACTIONS_AUTHORIZE_DEFAULT = "transactions/authorize".freeze
    private_constant :CONFIG_MASTER_METRICS_TRANSACTIONS_AUTHORIZE_DEFAULT

    @configuration = Configuration::Loader.new

    # assign @configuration first, since code can depend on the attr_reader
    @configuration.tap do |config|
      config.request_loggers = [:text]
      config.workers_logger_formatter = :text

      # Add configuration sections
      config.add_section(:queues, :master_name, :username, :password, :ssl, :ssl_params, :sentinels,
                         :sentinel_username, :sentinel_password, :role, :connect_timeout, :read_timeout, :write_timeout,
                         :max_connections)
      config.add_section(:redis, :url, :proxy, :username, :password, :ssl, :ssl_params, :sentinels,
                         :sentinel_username, :sentinel_password, :role, :connect_timeout, :read_timeout, :write_timeout,
                         :max_connections, :async)
      config.add_section(:hoptoad, :service, :api_key)
      config.add_section(:internal_api, :user, :password)
      config.add_section(:master, :metrics)
      config.add_section(:worker_prometheus_metrics, :enabled, :port)
      config.add_section(:opentelemetry, :enabled)

      config.add_section(
          :async_worker,

          # Max number of jobs in the reactor
          :max_concurrent_jobs,
          # Max number of jobs in memory pending to be added to the reactor
          :max_pending_jobs,
          # Seconds to wait before fetching more jobs when the number of jobs
          # in memory has reached max_pending_jobs.
          :seconds_before_fetching_more
      )

      # Configure nested fields
      master_metrics = [:transactions, :transactions_authorize]
      config.master.metrics = Struct.new(*master_metrics).new

      config.legacy_referrer_filters = false

      config.load!([
        '/etc/3scale_backend.conf',
        '~/.3scale_backend.conf',
        ENV['CONFIG_FILE']
      ].compact)

      ## this means that there will be a NotifyJob for every X notifications (this is
      ## the call to master)
      config.notification_batch = parse_int(config.notification_batch,
                                            NOTIFICATION_BATCH_DEFAULT)

      # Assign default values to some configuration values
      # that might been set in the config file but their
      # environment variables not, or not have been set
			# but should always have at least a default value.
			# Also make sure that what we have is a String, just in case
      # a type of data different than a String has been
			# assigned to this configuration parameter
      config.master.metrics.transactions = config.master.metrics.transactions.to_s
      if config.master.metrics.transactions.empty?
        config.master.metrics.transactions = CONFIG_MASTER_METRICS_TRANSACTIONS_DEFAULT
      end
      config.master.metrics.transactions_authorize = config.master.metrics.transactions_authorize.to_s
      if config.master.metrics.transactions_authorize.empty?
        config.master.metrics.transactions_authorize = CONFIG_MASTER_METRICS_TRANSACTIONS_AUTHORIZE_DEFAULT
      end

      # often we don't have a log_file setting - generate it here from
      # the log_path setting.
      log_file = config.log_file
      if !log_file || log_file.empty?
        log_path = config.log_path
        config.log_file = if log_path && !log_path.empty?
                            if File.stat(log_path).ftype == 'directory'
                              "#{log_path}/backend_logger.log"
                            else
                              log_path
                            end
                          else
                            ENV['CONFIG_LOG_FILE'] || STDOUT
                          end
      end
    end
  end
end
