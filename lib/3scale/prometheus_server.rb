# When required, starts the prometheus metrics server for the listener if the
# CONFIG_LISTENER_PROMETHEUS_METRICS_ENABLED env is set to true.

require_relative '../3scale/backend/listener_metrics'

# Config is not loaded at this point, so read ENV instead.
if ENV['CONFIG_LISTENER_PROMETHEUS_METRICS_ENABLED'].to_s.downcase.freeze == 'true'.freeze
  prometheus_port = ENV['CONFIG_LISTENER_PROMETHEUS_METRICS_PORT']
  ThreeScale::Backend::ListenerMetrics.start_metrics_server(prometheus_port)
end
