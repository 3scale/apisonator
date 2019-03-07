require '3scale/backend/worker_metrics'

module ThreeScale
  module Backend
    describe Worker do
      include SpecHelpers::ConfigHelper

      describe '.new' do
        after(:all) { reset_worker_prometheus_metrics_state }

        context 'when Prometheus metrics are enabled' do
          before { enable_worker_prometheus_metrics }

          it 'starts the metrics server' do
            expect(WorkerMetrics).to receive(:start_metrics_server)
            Worker.new
          end
        end

        context 'when Prometheus metrics are disabled' do
          before { disable_worker_prometheus_metrics }

          it 'does not start the metrics server' do
            expect(WorkerMetrics).not_to receive(:start_metrics_server)
            Worker.new
          end
        end
      end
    end
  end
end
