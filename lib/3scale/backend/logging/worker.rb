module ThreeScale
  module Backend
    module Logging
      class Worker
        include Configurable

        module PlainText
          private

          def logger_formatter
            proc do |severity, datetime, _progname, msg|
              "#{severity} #{Process.pid} #{formatted_datetime(datetime)} #{msg}\n"
            end
          end

          def formatted_datetime(datetime)
            datetime.getutc.strftime("[%d/%b/%Y %H:%M:%S %Z]".freeze)
          end
        end
        private_constant :PlainText

        module Json
          STRING_COMMON_FIELDS = [:job_class].freeze
          private_constant :STRING_COMMON_FIELDS

          FLOAT_COMMON_FIELDS = [:runtime, :run_plus_queued_time].freeze
          private_constant :FLOAT_COMMON_FIELDS

          INT_COMMON_FIELDS = [:memoizer_size, :memoizer_count, :memoizer_hits].freeze
          private_constant :INT_COMMON_FIELDS

          COMMON_LOG_FIELDS = (STRING_COMMON_FIELDS +
                               FLOAT_COMMON_FIELDS +
                               INT_COMMON_FIELDS).freeze
          private_constant :COMMON_LOG_FIELDS

          private

          def logger_formatter
            proc do |severity, datetime, _progname, msg|
              common_fields = { severity: severity,
                                pid: Process.pid,
                                time: datetime.getutc.to_s }

              # When there is an error, the msg does not contain run times and
              # memoizer stats.
              msg_fields = if severity == 'INFO'.freeze
                             formatted_msg(msg)
                           else
                             { msg: msg }
                           end

              common_fields.merge(msg_fields).to_json + "\n".freeze
            end
          end

          def formatted_msg(msg)
            # The format of the message depends on the kind of background job
            # that sends it:
            # job_class -variable_part- run_time run_time+queued_time
            # memoizer_size memoizer_count memoizer_hits.
            # -variable_part- depends on the kind of job. It might contain app
            # ids, a message (with spaces), etc. The rest of the message is
            # common for all the jobs. For now, we discard the variable part.
            fields = msg.split(' '.freeze)
            common_field_values = [fields.first] + fields.last(5)
            res = Hash[COMMON_LOG_FIELDS.zip(common_field_values)]

            FLOAT_COMMON_FIELDS.each do |field|
              res[field] = res[field].to_f
            end

            INT_COMMON_FIELDS.each do |field|
              res[field] = res[field].to_i
            end

            res
          end
        end
        private_constant :Json

        extend(configuration.workers_logger_formatter == :json ? Json : PlainText)

        class << self
          def configure_logging(worker_class, workers_log_file)
            log_file = workers_log_file || configuration.workers_log_file || File::NULL

            args = log_file.empty? ? [] : [log_file]
            Logging.enable! on: worker_class.singleton_class, with_args: args do |logger|
              logger.formatter = logger_formatter

              # At this point, we've already configured the logger for Backend
              # (used in Listeners and rake tasks). We can reuse the notify proc
              # defined there.
              logger.define_singleton_method(:notify, backend_logger_notify_proc)
            end
          end

          private

          def backend_logger_notify_proc
            Backend.logger.method(:notify).to_proc
          end
        end
      end
    end
  end
end
