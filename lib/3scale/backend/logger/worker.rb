module ThreeScale
  module Backend
    class Logger
      class Worker
        include Configurable

        class << self
          def configure_logging(worker_class, workers_log_file)
            log_file = workers_log_file || configuration.workers_log_file || '/dev/null'

            Logging.enable! on: worker_class.singleton_class, with: log_file do |logger|
              logger.formatter = logger_formatter

              # At this point, we've already configured the logger for Backend
              # (used in Listeners and rake tasks). We can reuse the notify proc
              # defined there.
              logger.define_singleton_method(:notify, backend_logger_notify_proc)
            end
          end

          private

          def logger_formatter
            if configuration.workers_logger_formatter == :json
              json_logger_formatter
            else
              default_logger_formatter
            end
          end

          def default_logger_formatter
            proc do |severity, datetime, _progname, msg|
              "#{severity} #{Process.pid} #{formatted_datetime(datetime)} #{msg}\n"
            end
          end

          # This method logs severity, pid, time, and msg. It would be
          # interesting to change the code in the workers so that we can break
          # down that 'msg' and get things like provider_key, service_id, etc.
          def json_logger_formatter
            proc do |severity, datetime, _progname, msg|
              { severity: severity,
                pid: Process.pid,
                time: formatted_datetime(datetime),
                msg: msg }.to_json + "\n".freeze
            end
          end

          def formatted_datetime(datetime)
            datetime.getutc.strftime("[%d/%b/%Y %H:%M:%S %Z]".freeze)
          end

          def backend_logger_notify_proc
            Backend.logger.method(:notify).to_proc
          end
        end
      end
    end
  end
end
