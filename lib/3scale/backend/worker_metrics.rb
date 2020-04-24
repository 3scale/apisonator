require 'yabeda/prometheus'

Yabeda.configure do
  group :apisonator_worker do
    counter :job_count do
      comment "Total number of jobs processed"
      tags %i[type]
    end

    histogram :job_runtime do
      comment "How long jobs take to run"
      unit :seconds
      tags %i[type]
      # Most requests will be under 100ms, so use a higher granularity from there
      buckets [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1, 0.25, 0.5, 0.75, 1]
    end
  end
end
Yabeda.configure!

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
