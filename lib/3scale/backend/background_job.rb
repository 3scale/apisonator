module ThreeScale
  module Backend

    class BackgroundJob

      class << self
        def perform(*args)
          @args = args || []
          with_logging do
            perform_logged(*args)
          end
        end

        def perform_logged
          raise "This should be overloaded."
        end

        private

        def enqueue_time
          @args.last or raise('Enqueue time not specified')
        end

        def with_logging
          @success_log_message = @error_log_message = nil

          start_time = Time.now.getutc
          yield
          stats_mem = Memoizer.stats
          end_time = Time.now.getutc

          if success?
            Worker.logger.info("#{log_class_name} " + success_log_message +
              "#{(end_time - start_time).round(5)} " +
              "#{(end_time.to_f - enqueue_time).round(5)} "+
              "#{stats_mem[:size]} #{stats_mem[:count]} #{stats_mem[:hits]}")
          else
            Worker.logger.error("#{log_class_name} " + error_log_message)
          end
        end

        def success_log_message
          @success_log_message or raise("This should be set.")
        end

        def error_log_message
          @error_log_message or raise("This should be set.")
        end

        def success?
          @error_log_message.nil? || @error_log_message.empty?
        end

        def log_class_name
          self.name.split('::').last
        end
      end
    end
  end
end
