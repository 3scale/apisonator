require '3scale/backend/worker_metrics'
require '3scale/backend/worker_sync'

require 'net/http'

module ThreeScale
  module Backend
    describe WorkerMetrics do
      include SpecHelpers::ConfigHelper

      let(:provider_key) { 'a_provider_key' }
      let(:service_id) { 'a_service_id' }
      let(:app_id) { 'an_app_id' }
      let(:metric_id) { 'a_metric_id' }
      let(:metric_name) { 'hits' }

      let(:config) { Backend.configuration }

      let(:n_jobs) { 5 }

      let(:metrics_endpoint) { '/metrics' }
      let(:metrics_port) { 9394 }

      # For this test, it does not really matter if we use a sync or async
      # worker.
      let(:worker) { WorkerSync.new(one_off: true) }

      default_metrics_enabled = Backend.configuration.worker_prometheus_metrics
      original_redis_async = Backend.configuration.redis_async

      before do
        config.redis.async = false
        Service.save!(provider_key: provider_key, id: service_id)
        Application.save(service_id: service_id, id: app_id, state: :active)
        Metric.save(service_id: service_id, id: metric_id, name: metric_name)
      end

      after do
        config.worker_prometheus_metrics.enabled = default_metrics_enabled
        config.redis.async = original_redis_async
      end

      context 'when prometheus metrics are enabled' do
        before do
          enable_worker_prometheus_metrics
          WorkerMetrics.start_metrics_server
          report_jobs(n_jobs)
          process_jobs(worker, n_jobs)
        end

        after do
          shutdown_metrics_server
        end

        it 'exposes them' do
          sleep(1) # The web server takes a bit to start

          resp = Net::HTTP.get('localhost', metrics_endpoint, metrics_port)

          expect(resp).to match(
/TYPE apisonator_worker_job_count counter
# HELP apisonator_worker_job_count Total number of jobs processed
apisonator_worker_job_count{type="ReportJob"} #{n_jobs}(\.0)?
# TYPE apisonator_worker_job_runtime_seconds histogram
# HELP apisonator_worker_job_runtime_seconds How long jobs take to run
.*
apisonator_worker_job_runtime_seconds_sum{type="ReportJob"} \d+\.\d+
apisonator_worker_job_runtime_seconds_count{type="ReportJob"} \d+\.\d+
/m)
        end
      end

      context 'when prometheus metrics are enabled on a given port' do
        let(:port) { 7777 }

        before do
          enable_worker_prometheus_metrics
          set_worker_prometheus_metrics_port(port)
          WorkerMetrics.start_metrics_server
        end

        after do
          reset_worker_prometheus_metrics_port
          shutdown_metrics_server
        end

        it 'exposes the metrics' do
          sleep(1) # The web server takes a bit to start

          resp = Net::HTTP.get('localhost', metrics_endpoint, port)

          expect(resp).not_to be_nil
        end
      end

      context 'when prometheus metrics are not enabled' do
        before do
          disable_worker_prometheus_metrics
          report_jobs(n_jobs)
          process_jobs(worker, n_jobs)
        end

        it 'does not expose them' do
          sleep(1) # The web server takes a bit to start

          expect { Net::HTTP.get('localhost', metrics_endpoint, metrics_port) }
            .to raise_error(SystemCallError)
        end
      end

      private

      def report_jobs(num)
        without_resque_spec do
          num.times do
            Transactor.report(
                provider_key,
                service_id,
                0 => { app_id: app_id, usage: { metric_name => 1 } }
            )
          end
        end
      end

      def process_jobs(worker, num)
        without_resque_spec do
          num.times { worker.work }
        end
      end

      def shutdown_metrics_server
        # Yabeda does not expose this
        ::Rack::Handler::WEBrick.shutdown
      end
    end
  end
end
