module ThreeScale
  module Backend
    class Logger
      class Worker
        include Configurable

        class << self
          def configure_logging(worker_class, workers_log_file)
            log_file = workers_log_file || configuration.workers_log_file || '/dev/null'

            Logging.enable! on: worker_class.singleton_class, with: log_file do |logger|
              logger.formatter = default_logger_formatter

              # At this point, we've already configured the logger for Backend
              # (used in Listeners and rake tasks). We can reuse the notify proc
              # defined there.
              logger.define_singleton_method(:notify, backend_logger_notify_proc)
            end
          end

          private

          def default_logger_formatter
            proc do |severity, datetime, _progname, msg|
              "#{severity} #{Process.pid} #{formatted_datetime(datetime)} #{msg}\n"
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
