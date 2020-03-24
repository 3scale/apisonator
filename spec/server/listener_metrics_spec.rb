require_relative '../spec_helper'
require 'net/http'
require '3scale/backend'

module ThreeScale
  module Backend
    describe Listener do
      # The port is not the standard one to avoid clashes with other tests
      let(:listener_port) { 4000 }
      let(:listener_host) { 'localhost' }
      let(:config_file) { '/tmp/.3scale_backend_listener_metrics_test.config' }
      let(:metrics_endpoint) { '/metrics' }
      let(:metrics_port) { 9394 }

      context 'when listener metrics are enabled' do
        let(:provider_key) { 'pk' }
        let(:service_id) { '1' }
        let(:app_id) { '1' }
        let(:user_key) { 'uk' }
        let(:metric_id) { '1' }
        let(:metric_name) { 'hits' }

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
            write_config_file(config_file)
            start_listener(config_file, true, listener_port, metrics_port, server)

            ThreeScale::Backend::Service.save!(
              provider_key: provider_key, id: service_id
            )
            ThreeScale::Backend::Application.save(
              service_id: service_id, id: app_id, state: :active
            )
            ThreeScale::Backend::Application.save_id_by_key(
              service_id, user_key, app_id
            )
            ThreeScale::Backend::Metric.save(
              service_id: service_id, id: metric_id, name: metric_name
            )

            # Do requests to generate some metrics:
            # - 1 authorize (authorized)
            # - 2 authreps authorized
            # - 2 authreps unauthorized, one that returns 403 and another that returns 404
            do_auth(listener_host, listener_port, args)
            2.times { do_authrep(listener_host, listener_port, args) }
            do_authrep(listener_host, listener_port, args.merge(user_key: 'invalid')) # 403
            do_authrep(listener_host, listener_port, args.merge(metric_name: 'invalid')) # 404
          end

          after do
            stop_listener(listener_port, server)
            delete_config_file(config_file)
          end

          it 'shows metrics in Prometheus format' do
            metrics_resp = Net::HTTP.get(listener_host, metrics_endpoint, metrics_port)

            # These are some lines that we know that should be part of the output.
            check_lines = [
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

            expect(metrics_resp).to include(*check_lines)
          end
        end

        context 'running Puma' do
          it_behaves_like 'listener with metrics', :puma
        end

        context 'running Falcon' do
          it_behaves_like 'listener with metrics', :falcon
        end
      end

      context 'when listener metrics are not enabled' do
        shared_examples_for 'listener without metrics' do |server|
          before do
            write_config_file(config_file)
            start_listener(config_file, false, listener_port, metrics_port, server)
          end

          after do
            stop_listener(listener_port, server)
            delete_config_file(config_file)
          end

          it 'does not open the metrics port' do
            expect { Net::HTTP.get(listener_host, metrics_endpoint, metrics_port) }
              .to raise_error(Errno::EADDRNOTAVAIL)
          end
        end

        context 'running Puma' do
          it_behaves_like 'listener without metrics', :puma
        end

        context 'running Falcon' do
          it_behaves_like 'listener without metrics', :falcon
        end
      end

      private

      def write_config_file(path)
        File.open(path, 'w+') do |f|
          f.write("ThreeScale::Backend.configure do |config|\n"\
              " config.listener_prometheus_metrics.enabled = ENV['CONFIG_LISTENER_PROMETHEUS_METRICS_ENABLED'].to_s == 'true'\n"\
              " config.listener_prometheus_metrics.port = ENV['CONFIG_LISTENER_PROMETHEUS_METRICS_PORT']\n"\
              "end\n")
        end
      end

      def delete_config_file(path)
        File.delete(path)
      end

      def start_listener(config_file, metrics_enabled, listener_port, metrics_port, server)
        envs = {
          LISTENER_WORKERS: 2, # To check that metrics are accurate with multiple workers
          CONFIG_LISTENER_PROMETHEUS_METRICS_ENABLED: metrics_enabled,
          CONFIG_LISTENER_PROMETHEUS_METRICS_PORT: metrics_port,
          CONFIG_FILE: config_file
        }
        envs_str = envs.map { |env, val| "#{env}=#{val}" }.join(' ')

        # Send logs to /dev/null to avoid cluttering the output
        start_ok = system("#{envs_str} bundle exec bin/3scale_backend " +
                          "-s #{server} start -p #{listener_port} 2> /dev/null &")
        raise 'Failed to start Puma' unless start_ok
        sleep(2) # Give it some time to be ready
      end

      def stop_listener(port, server)
        if server == :puma
          system("bundle exec bin/3scale_backend stop -p #{port}")
        else # stop not implemented in Falcon
          # Need to send 2 SIGTERMs because a bug in falcon v0.35.x
          # https://github.com/socketry/falcon/issues/109
          2.times { system("pkill -u #{Process.euid} -f \"ruby .*falcon\"") }
        end
        sleep(2) # Give it some time to stop
      end

      def do_auth(listener_host, listener_port, args)
        query = auth_query(args)
        Net::HTTP.get(listener_host, query, listener_port)
      end

      def do_authrep(listener_host, listener_port, args)
        query = authrep_query(args)
        Net::HTTP.get(listener_host, query, listener_port)
      end

      def auth_query(args)
        '/transactions/authorize.xml?' + parsed_query_args(args)
      end

      def authrep_query(args)
        '/transactions/authrep.xml?' + parsed_query_args(args)
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
