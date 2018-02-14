require '3scale/backend/configuration/loader'
require '3scale/backend/environment'
require '3scale/backend/configurable'

module ThreeScale
  module Backend
    class << self
      attr_accessor :configuration

      def configure
        yield configuration
      end
    end

    @configuration = Configuration::Loader.new

    # assign @configuration first, since code can depend on the attr_reader
    @configuration.tap do |config|
      # To distinguish between SaaS and on-premises mode.
      config.saas = true

      config.request_loggers = [:text]
      config.workers_logger_formatter = :text

      # Add configuration sections
      config.add_section(:queues, :master_name, :sentinels,
                         :connect_timeout, :read_timeout, :write_timeout)
      config.add_section(:redis, :proxy, :nodes,
                         :connect_timeout, :read_timeout, :write_timeout)
      config.add_section(:analytics_redis, :server,
                         :connect_timeout, :read_timeout, :write_timeout)
      config.add_section(:hoptoad, :service, :api_key)
      config.add_section(:stats, :bucket_size)
      config.add_section(:redshift, :host, :port, :dbname, :user, :password)
      config.add_section(:statsd, :host, :port)
      config.add_section(:internal_api, :user, :password)
      config.add_section(:oauth, :max_token_size)

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
      config.load!([
        '/etc/3scale_backend.conf',
        '~/.3scale_backend.conf',
        ENV['CONFIG_FILE']
      ].compact)

      # can_create_event_buckets is just for our SaaS analytics system.
      # If SaaS has been set to false, we need to disable buckets too.
      config.can_create_event_buckets = false unless config.saas

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
