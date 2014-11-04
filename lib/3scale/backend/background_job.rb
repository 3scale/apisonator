module ThreeScale
  module Backend

    class BackgroundJob
      @queue = :main

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
          start_time = Time.now.getutc

          yield

          stats_mem = Memoizer.stats
          end_time = Time.now.getutc

          Worker.logger.info("#{log_class_name} " + success_log_message +
            "#{(end_time - start_time).round(5)} #{(end_time.to_f - enqueue_time).round(5)} "+
            "#{stats_mem[:size]} #{stats_mem[:count]} #{stats_mem[:hits]}")
        end

        def success_log_message
          @success_log_message || "OVERLOAD THIS "
        end

        def log_class_name
          self.name.split('::').last
        end
      end
    end
  end
end
