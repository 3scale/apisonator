module ThreeScale
  module Backend

    class BackgroundJob
      include Configurable

      EMPTY_HOOKS = [].freeze
      Error = Class.new StandardError

      class << self
        def perform(*args)
          perform_wrapper(args)
        end

        def perform_logged(*_args)
          raise "This should be overloaded."
        end

        # Disable hooks to improve performance. Profiling tests show that some
        # significant CPU resources were consumed sorting and filtering these.
        def hooks
          EMPTY_HOOKS
        end

        private

        def enqueue_time(args)
          args.last or raise('Enqueue time not specified')
        end

        def perform_wrapper(args)
          start_time = Time.now.getutc
          status_ok, message = perform_logged(*args)
          stats_mem = Memoizer.stats
          end_time = Time.now.getutc

          raise Error, 'No job message given' unless message
          prefix = log_class_name + ' ' + message

          if status_ok
            Worker.logger.info(prefix +
              " #{(end_time - start_time).round(5)}" +
              " #{(end_time.to_f - enqueue_time(args)).round(5)}"+
              " #{stats_mem[:size]} #{stats_mem[:count]} #{stats_mem[:hits]}")

            if configuration.worker_prometheus_metrics.enabled
              update_prometheus_metrics(end_time - start_time)
            end
          else
            Worker.logger.error("#{log_class_name} " + message)
          end
        end

        def log_class_name
          self.name.split('::').last
        end

        def update_prometheus_metrics(runtime)
          WorkerMetrics.increase_job_count(log_class_name)
          WorkerMetrics.report_runtime(log_class_name, runtime)
        end
      end
    end
  end
end
