require '3scale/backend/environment'
require '3scale/backend/configuration'
require '3scale/backend/logger'

module ThreeScale
  module Backend
    class << self

      private

      def configure_airbrake
        if configuration.saas
          require 'airbrake'
          Airbrake.configure do |config|
            config.api_key = configuration.hoptoad.api_key
            config.environment_name = environment
          end
        end
      end

      def enable_logging
        Logging.enable! on: self.singleton_class,
          with: [logs_file, 10] do |logger|
          logger.define_singleton_method(:notify, logger_notify_proc(logger))
        end
      end

      def logs_file
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

      def logger_notify_proc(logger)
        if airbrake_enabled?
          Airbrake.method(:notify).to_proc
        else
          logger.method(:error).to_proc
        end
      end

      def airbrake_enabled?
        defined?(Airbrake) && Airbrake.configuration.api_key
      end
    end

    configure_airbrake
    enable_logging
  end
end
