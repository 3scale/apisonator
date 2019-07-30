require 'yabeda/prometheus'

Yabeda.configure do
  group :apisonator_worker do
    counter :job_count, comment: "Total number of jobs processed"

    histogram :job_runtime do
      comment "How long jobs take to run"
      unit :seconds
      buckets [0.005, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1]
    end
  end
end

module ThreeScale
  module Backend
    class WorkerMetrics
      include Configurable

      def self.start_metrics_server
        # Yabeda does not accept the port as a param
        port = configuration.worker_prometheus_metrics.port
        ENV['PROMETHEUS_EXPORTER_PORT'] = port.to_s if port

        Yabeda::Prometheus::Exporter.start_metrics_server!
      end

      def self.increase_job_count(job_class_name)
        Yabeda.apisonator_worker.job_count.increment(
            { type: job_class_name }, by: 1
        )
      end

      def self.report_runtime(job_class_name, runtime)
        Yabeda.apisonator_worker.job_runtime.measure({ type: job_class_name }, runtime)
      end
    end
  end
end
