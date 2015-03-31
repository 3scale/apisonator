module ThreeScale
  module Backend

    class BackgroundJob

      Error = Class.new StandardError

      class << self
        def perform(*args)
          @args = args
          perform_wrapper
        end

        def perform_logged
          raise "This should be overloaded."
        end

        private

        def enqueue_time
          @args.last or raise('Enqueue time not specified')
        end

        def perform_wrapper
          start_time = Time.now.getutc
          status_ok, message = perform_logged(*@args)
          stats_mem = Memoizer.stats
          end_time = Time.now.getutc

          raise Error, 'No job message given' unless message
          prefix = log_class_name + ' ' + message

          if status_ok
            Worker.logger.info(prefix +
              " #{(end_time - start_time).round(5)}" +
              " #{(end_time.to_f - enqueue_time).round(5)}"+
              " #{stats_mem[:size]} #{stats_mem[:count]} #{stats_mem[:hits]}")
          else
            Worker.logger.error("#{log_class_name} " + message)
          end
        end

        def log_class_name
          self.name.split('::').last
        end
      end
    end
  end
end
