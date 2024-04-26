require 'net/http'
require '3scale/backend'

module ThreeScale
  module Backend
    # The port is not the standard one to avoid clashes with other tests
    LISTENER_PORT = 4000
    LISTENER_HOST = 'localhost'

    describe Listener do
      let(:metrics_endpoint) { '/metrics' }
      let(:metrics_port) { 9394 }

      context 'when listener metrics are enabled' do
        let(:provider_key) { 'pk' }
        let(:service_id) { '1' }
        let(:app_id) { '1' }
        let(:user_key) { 'uk' }
        let(:metric_id) { '1' }
        let(:metric_name) { 'hits' }
        let(:service_token) { 'some_token' }
        let(:plan_id) { '1' }
        let(:limit_period) { 'hour' }

        let(:args) do
          {
            provider_key: provider_key,
            service_id: service_id,
            app_id: app_id,
            user_key: user_key,
            metric_id: metric_id,
            metric_name: metric_name,
            metric_val: 1,
          }
        end

        shared_examples_for 'listener with metrics' do |server|
          before do
            start_listener(true, LISTENER_PORT, metrics_port, server)

            ThreeScale::Backend::Service.save!(
              provider_key: provider_key, id: service_id
            )

            ThreeScale::Backend::Application.save(
              service_id: service_id, id: app_id, state: :active, plan_id: plan_id
            )

            ThreeScale::Backend::Application.save_id_by_key(
              service_id, user_key, app_id
            )

            ThreeScale::Backend::Metric.save(
              service_id: service_id, id: metric_id, name: metric_name
            )

            ThreeScale::Backend::ServiceToken.save(service_token, service_id)

            ThreeScale::Backend::UsageLimit.save(
              service_id: service_id, plan_id: plan_id, metric_id: metric_id, hour: 10
            )
          end

          after do
            stop_listener(LISTENER_PORT, server)
          end

          it 'shows Prometheus metrics for auths and reports' do
            # Do requests to generate some metrics:
            # - 1 authorize (authorized)
            # - 2 authreps authorized
            # - 2 authreps unauthorized, one that returns 403 and another that returns 404
            # - A valid request to the internal API (get services) and an invalid one.
            do_auth(args)
            2.times { do_authrep(args) }
            do_authrep(args.merge(user_key: 'invalid')) # 403
            do_authrep(args.merge(metric_name: 'invalid')) # 404

            metrics_resp = Net::HTTP.get(LISTENER_HOST, metrics_endpoint, metrics_port)

            # These are some lines that we know that should be part of the output.
            auth_report_lines = [
              '# TYPE apisonator_listener_response_codes counter',
              '# HELP apisonator_listener_response_codes Response codes',
              'apisonator_listener_response_codes{request_type="authrep",resp_code="2xx"} 2.0',
              'apisonator_listener_response_codes{request_type="authorize",resp_code="2xx"} 1.0',
              'apisonator_listener_response_codes{request_type="authrep",resp_code="403"} 1.0',
              'apisonator_listener_response_codes{request_type="authrep",resp_code="404"} 1.0',
              '# TYPE apisonator_listener_response_times_seconds histogram',
              '# HELP apisonator_listener_response_times_seconds Response times',
              'apisonator_listener_response_times_seconds_count{request_type="authorize"} 1.0',
              'apisonator_listener_response_times_seconds_count{request_type="authrep"} 4.0',
            ]

            expect(metrics_resp).to include(*auth_report_lines)
          end

          it 'shows Prometheus metrics for the internal API' do
            internal_api_lines = [
              '# TYPE apisonator_listener_internal_api_response_codes counter',
              '# HELP apisonator_listener_internal_api_response_codes Response codes',
              '# TYPE apisonator_listener_internal_api_response_times_seconds histogram',
              '# HELP apisonator_listener_internal_api_response_times_seconds Response times',
            ]

            request_types = [
              [
                'alerts',
                proc { get_alerts_internal_api(service_id) }
              ],
              [
                'application_keys',
                proc { get_app_keys_internal_api(service_id, app_id) }
              ],
              [
                'application_referrer_filters',
                proc { get_app_referrer_filters_internal_api(service_id, app_id) }
              ],
              [
                'applications',
                proc { get_app_internal_api(service_id, app_id) }
              ],
              [
                'errors',
                proc { get_errors_internal_api(service_id) }
              ],
              [
                'events',
                proc { get_events_internal_api }
              ],
              [
                'metrics',
                proc { get_metric_internal_api(service_id, metric_id) }
              ],
              [
                'service_tokens',
                proc { get_service_token_internal_api(service_token, service_id) }
              ],
              [
                'services',
                proc { get_service_internal_api(service_id) }
              ],
              [
                'stats',
                proc { delete_stats_internal_api(service_id) }
              ],
              [
                'usage_limits',
                proc { get_usage_limits_internal_api(service_id, plan_id, metric_id, limit_period) }
              ],
              [
                'utilization',
                proc { get_utilization_internal_api(service_id, app_id) }
              ]
            ]

            request_types.each do |(request_type, blk)|
              n_calls = rand(1..5)
              n_calls.times &blk
              internal_api_lines << "apisonator_listener_internal_api_response_codes" +
                                    "{request_type=\"#{request_type}\",resp_code=\"2xx\"} #{n_calls}.0"
              internal_api_lines << "apisonator_listener_internal_api_response_times_seconds_count" +
                                    "{request_type=\"#{request_type}\"} #{n_calls}.0"
            end

            metrics_resp = Net::HTTP.get(LISTENER_HOST, metrics_endpoint, metrics_port)

            expect(metrics_resp).to include(*internal_api_lines)
          end
        end

        if ThreeScale::Backend.configuration.redis.async
          context 'running Falcon' do
            it_behaves_like 'listener with metrics', :falcon
          end
        else
          context 'running Puma' do
            it_behaves_like 'listener with metrics', :puma
          end
        end
      end

      context 'when listener metrics are not enabled' do
        shared_examples_for 'listener without metrics' do |server|
          before do
            start_listener(false, LISTENER_PORT, metrics_port, server)
          end

          after do
            stop_listener(LISTENER_PORT, server)
          end

          it 'does not open the metrics port' do
            expect { Net::HTTP.get(LISTENER_HOST, metrics_endpoint, metrics_port) }
              .to raise_error(SystemCallError)
          end
        end

        if ThreeScale::Backend.configuration.redis.async
          context 'running Falcon' do
            it_behaves_like 'listener without metrics', :falcon
          end
        else
          context 'running Puma' do
            it_behaves_like 'listener without metrics', :puma
          end
        end
      end

      private

      def start_listener(metrics_enabled, listener_port, metrics_port, server)
        envs = {
          LISTENER_WORKERS: 2, # To check that metrics are accurate with multiple workers
          CONFIG_LISTENER_PROMETHEUS_METRICS_ENABLED: metrics_enabled,
          CONFIG_LISTENER_PROMETHEUS_METRICS_PORT: metrics_port,
        }
        envs_str = envs.map { |env, val| "#{env}=#{val}" }.join(' ')

        # Send logs to /dev/null to avoid cluttering the output
        start_ok = system("#{envs_str} bundle exec bin/3scale_backend " +
                          "-s #{server} start -p #{listener_port} 2> /dev/null &")
        raise 'Failed to start Listener' unless start_ok

        if server == :puma
          wait_for_puma_control_socket
        else
          # Give it some time to start
          sleep 2
        end
      end

      def stop_listener(port, server)
        if server == :puma
          system("bundle exec bin/3scale_backend stop -p #{port}")
          sleep(2) # Give it some time to stop
        else # stop not implemented in Falcon
          system("pkill -u #{Process.euid} -f \"ruby .*falcon\"")
          sleep(2) # Give it some time to stop

          # TODO: investigate why occasionally Falcon does not kill its children
          # processes ("Falcon Server").
          if system("pkill -u #{Process.euid} -f \"Falcon Server\"")
            sleep(2)
            system("pkill --signal SIGKILL -u #{Process.euid} -f \"Falcon Server\"")
          end
        end
      end

      def wait_for_puma_control_socket
        Timeout::timeout(5) do
          until system("bundle exec bin/3scale_backend status")
            sleep 0.1
          end
        end
      end

      def do_get_req(path)
        Net::HTTP.get(LISTENER_HOST, path, LISTENER_PORT)
      end

      def do_delete_req(path)
        Net::HTTP.new(LISTENER_HOST, LISTENER_PORT).delete(path)
      end

      def do_auth(args)
        do_get_req(auth_query(args))
      end

      def do_authrep(args)
        do_get_req(authrep_query(args))
      end

      def auth_query(args)
        '/transactions/authorize.xml?' + parsed_query_args(args)
      end

      def authrep_query(args)
        '/transactions/authrep.xml?' + parsed_query_args(args)
      end

      def do_internal_api_get_req(path)
        do_get_req("/internal#{path}")
      end

      def do_internal_api_delete_req(path)
        do_delete_req("/internal#{path}")
      end

      def get_service_internal_api(service_id)
        do_internal_api_get_req("/services/#{service_id}")
      end

      def get_alerts_internal_api(service_id)
        do_internal_api_get_req("/services/#{service_id}/alert_limits/")
      end

      def get_app_keys_internal_api(service_id, app_id)
        do_internal_api_get_req("/services/#{service_id}/applications/#{app_id}/keys/")
      end

      def get_app_referrer_filters_internal_api(service_id, app_id)
        do_internal_api_get_req("/services/#{service_id}/applications/#{app_id}/referrer_filters")
      end

      def get_app_internal_api(service_id, app_id)
        do_internal_api_get_req("/services/#{service_id}/applications/#{app_id}")
      end

      def get_errors_internal_api(service_id)
        do_internal_api_get_req("/services/#{service_id}/errors/")
      end

      def get_events_internal_api
        do_internal_api_get_req("/events/")
      end

      def get_metric_internal_api(service_id, metric_id)
        do_internal_api_get_req("/services/#{service_id}/metrics/#{metric_id}")
      end

      def get_service_token_internal_api(token, service_id)
        do_internal_api_get_req("/service_tokens/#{token}/#{service_id}/provider_key")
      end

      def delete_stats_internal_api(service_id)
        do_internal_api_delete_req("/services/#{service_id}/stats")
      end

      def get_usage_limits_internal_api(service_id, plan_id, metric_id, period)
        do_internal_api_get_req("/services/#{service_id}/plans/#{plan_id}/usagelimits/" +
                                "#{metric_id}/#{period}")
      end

      def get_utilization_internal_api(service_id, app_id)
        do_internal_api_get_req("/services/#{service_id}/applications/#{app_id}/utilization/")
      end

      def parsed_query_args(args)
        "provider_key=#{args[:provider_key]}" +
          "&service_id=#{args[:service_id]}" +
          "&user_key=#{args[:user_key]}" +
          "&usage%5B#{args[:metric_name]}%5D=#{args[:metric_val]}"
      end
    end
  end
end
