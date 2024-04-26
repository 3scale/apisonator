require '3scale/backend/worker_metrics'

module ThreeScale
  module Backend
    describe BackgroundJob do
      include SpecHelpers::ConfigHelper

      class FooJob < BackgroundJob

        def self.perform_logged(*args)
          sleep 0.15
          [true, 'job was successful']
        end
      end

      class BarJob < BackgroundJob
        def self.perform_logged(*args); end
      end

      describe 'logging a proper Job' do
        before do
          allow(Worker).to receive(:logger).and_return(
            ::Logger.new(@log = StringIO.new))
          FooJob.perform(Time.now.getutc.to_f)
          @log.rewind
        end

        it 'logs class name' do
          expect(@log.read).to match /FooJob/
        end

        it 'logs job message' do
          expect(@log.read).to match /job was successful/
        end

        it 'logs execution time' do
          expect(@log.read).to match /0\.15/
        end
      end

      describe 'invalid Job' do
        before { ThreeScale::Backend::Worker.new }

        it 'complains when you don\'t set a log message' do
          expect { BarJob.perform() }.to raise_error(
            BackgroundJob::Error, 'No job message given')
        end
      end

      describe '.perform' do
        after(:all) { reset_worker_prometheus_metrics_state }

        context 'when Prometheus metrics are enabled' do
          before { enable_worker_prometheus_metrics }

          it 'reports type of job performed and runtime' do
            expect(WorkerMetrics).to receive(:increase_job_count).with('FooJob')

            expect(WorkerMetrics).to receive(:report_runtime)
                                 .with('FooJob', satisfy { |v| v > 0 })

            FooJob.perform(Time.now.getutc.to_f)
          end
        end

        context 'when Prometheus metrics are disabled' do
          before { disable_worker_prometheus_metrics }

          it 'does not update any Prometheus metric' do
            expect(WorkerMetrics).not_to receive(:increase_job_count)
            expect(WorkerMetrics).not_to receive(:report_runtime)

            FooJob.perform(Time.now.getutc.to_f)
          end
        end
      end
    end
  end
end

