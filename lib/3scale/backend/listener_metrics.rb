require 'yabeda/prometheus'
require 'rack'

module ThreeScale
  module Backend
    class ListenerMetrics
      AUTH_AND_REPORT_REQUEST_TYPES = {
        '/transactions/authorize.xml' => 'authorize',
        '/transactions/oauth_authorize.xml' => 'authorize_oauth',
        '/transactions/authrep.xml' => 'authrep',
        '/transactions/oauth_authrep.xml' => 'authrep_oauth',
        '/transactions.xml' => 'report'
      }
      private_constant :AUTH_AND_REPORT_REQUEST_TYPES

      # Only the first match is taken into account, that's why for example,
      # "/\/services\/.*\/stats/" needs to appear before "/\/services/"
      INTERNAL_API_PATHS = [
        [/\/services\/.*\/alert_limits/, 'alerts'.freeze],
        [/\/services\/.*\/applications\/.*\/keys/, 'application_keys'.freeze],
        [/\/services\/.*\/applications\/.*\/referrer_filters/, 'application_referrer_filters'.freeze],
        [/\/services\/.*\/applications\/.*\/utilization/, 'utilization'.freeze],
        [/\/services\/.*\/applications/, 'applications'.freeze],
        [/\/services\/.*\/errors/, 'errors'.freeze],
        [/\/events/, 'events'.freeze],
        [/\/services\/.*\/metrics/, 'metrics'.freeze],
        [/\/service_tokens/, 'service_tokens'.freeze],
        [/\/services\/.*\/stats/, 'stats'.freeze],
        [/\/services\/.*\/plans\/.*\/usagelimits/, 'usage_limits'.freeze],
        [/\/services/, 'services'.freeze],
      ].freeze
      private_constant :INTERNAL_API_PATHS

      # Most requests will be under 100ms, so use a higher granularity from there
      TIME_BUCKETS = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1, 0.25, 0.5, 0.75, 1]
      private_constant :TIME_BUCKETS

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
          req_type = req_type(path)
          prometheus_group = prometheus_group(req_type)

          Yabeda.send(prometheus_group).response_codes.increment(
            {
              request_type: req_type,
              resp_code: code_group(resp_code)
            },
            by: 1
          )
        end

        def report_response_time(path, request_time)
          req_type = req_type(path)
          prometheus_group = prometheus_group(req_type)

          Yabeda.send(prometheus_group).response_times.measure(
            { request_type: req_type },
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
                buckets TIME_BUCKETS
              end
            end

            group :apisonator_listener_internal_api do
              counter :response_codes do
                comment 'Response codes'
                tags %i[request_type resp_code]
              end

              histogram :response_times do
                comment 'Response times'
                unit :seconds
                tags %i[request_type]
                buckets TIME_BUCKETS
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

        def req_type(path)
          AUTH_AND_REPORT_REQUEST_TYPES[path] || internal_api_req_type(path)
        end

        def internal_api_req_type(path)
          (_regex, type) = INTERNAL_API_PATHS.find { |(regex, _)| regex.match path }
          type
        end

        # Returns the group as defined in .define_metrics
        def prometheus_group(request_type)
          if AUTH_AND_REPORT_REQUEST_TYPES.values.include? request_type
            :apisonator_listener
          else
            :apisonator_listener_internal_api
          end
        end
      end
    end
  end
end
