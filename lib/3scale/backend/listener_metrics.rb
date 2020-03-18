require 'yabeda/prometheus'
require 'rack'

module ThreeScale
  module Backend
    class ListenerMetrics
      REQUEST_TYPES = {
        '/transactions/authorize.xml' => 'authorize',
        '/transactions/oauth_authorize.xml' => 'authorize_oauth',
        '/transactions/authrep.xml' => 'authrep',
        '/transactions/oauth_authrep.xml' => 'authrep_oauth',
        '/transactions.xml' => 'report'
      }
      private_constant :REQUEST_TYPES

      class << self
        ERRORS_4XX_TO_TRACK = Set[403, 404, 409].freeze
        private_constant :ERRORS_4XX_TO_TRACK

        def start_metrics_server(port = nil)
          configure_data_store
          define_metrics

          # Yabeda does not accept the port as a param
          ENV['PROMETHEUS_EXPORTER_PORT'] = port.to_s if port
          Yabeda::Prometheus::Exporter.start_metrics_server!
        end

        def report_resp_code(path, resp_code)
          Yabeda.apisonator_listener.response_codes.increment(
            {
              request_type: REQUEST_TYPES[path],
              resp_code: code_group(resp_code)
            },
            by: 1
          )
        end

        def report_response_time(path, request_time)
          Yabeda.apisonator_listener.response_times.measure(
            { request_type: REQUEST_TYPES[path] },
            request_time
          )
        end

        private

        def configure_data_store
          # Needed to aggregate metrics across processes.
          # Ref: https://github.com/yabeda-rb/yabeda-prometheus#multi-process-server-support
          Dir['/tmp/prometheus/*.bin'].each do |file_path|
            File.unlink(file_path)
          end

          Prometheus::Client.config.data_store = Prometheus::Client::DataStores::DirectFileStore.new(
            dir: '/tmp/prometheus'
          )
        end

        def define_metrics
          Yabeda.configure do
            group :apisonator_listener do
              counter :response_codes do
                comment 'Response codes'
                tags %i[request_type resp_code]
              end

              histogram :response_times do
                comment 'Response times'
                unit :seconds
                tags %i[request_type]
                # Most requests will be under 100ms, so use a higher granularity from there
                buckets [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1, 0.25, 0.5, 0.75, 1]
              end
            end
          end

          # Note that this method raises if called more than once. Both
          # listeners and workers define their metrics, but that's fine because
          # a process cannot act as both.
          Yabeda.configure!
        end

        def code_group(resp_code)
          case resp_code
          when (200...300)
            '2xx'.freeze
          when (400...500)
            ERRORS_4XX_TO_TRACK.include?(resp_code) ? resp_code : '4xx'.freeze
          when (500...600)
            '5xx'.freeze
          else
            'unknown'.freeze
          end
        end
      end
    end
  end
end
