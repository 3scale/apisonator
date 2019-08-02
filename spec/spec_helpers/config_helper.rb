module SpecHelpers
  module ConfigHelper
    include ThreeScale::Backend::Configurable

    def enable_worker_prometheus_metrics
      prometheus_worker_metrics_opts.enabled = true
    end

    def disable_worker_prometheus_metrics
      prometheus_worker_metrics_opts.enabled = false
    end

    def reset_worker_prometheus_metrics_state
      disable_worker_prometheus_metrics
    end

    def set_worker_prometheus_metrics_port(port)
      prometheus_worker_metrics_opts.port = port
    end

    def reset_worker_prometheus_metrics_port
      prometheus_worker_metrics_opts.port = 9394
    end

    private

    def prometheus_worker_metrics_opts
      configuration.worker_prometheus_metrics
    end
  end
end
