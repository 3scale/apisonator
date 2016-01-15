require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/send_to_kinesis'

module ThreeScale
  module Backend
    module Stats
      describe SendToKinesis do
        subject { SendToKinesis }

        describe '.enable' do
          before { subject.disable }

          it 'makes .enabled? return true' do
            expect { subject.enable }.to change(subject, :enabled?).from(false).to(true)
          end
        end

        describe '.disable' do
          before { subject.enable }

          it 'makes .enabled? return false' do
            expect { subject.disable }.to change(subject, :enabled?).from(true).to(false)
          end
        end

        describe '.schedule_job' do
          context 'when kinesis is enabled' do
            before { subject.enable }

            context 'when there is at least one job already running' do
              before { subject.stub(:job_running?).and_return true }

              it 'does not schedule a kinesis job' do
                expect(Resque).not_to receive(:enqueue)
                subject.schedule_job
              end
            end

            context 'when there are not any jobs running' do
              before { subject.stub(:job_running?).and_return false }

              it 'schedules a kinesis job' do
                expect(Resque).to receive(:enqueue)
                subject.schedule_job
              end
            end
          end

          context 'when kinesis is disabled' do
            before { subject.disable }

            it 'does not schedule a kinesis job' do
              expect(Resque).not_to receive(:enqueue)
              subject.schedule_job
            end
          end
        end

        describe '.flush_pending_events' do
          let(:kinesis_adapter) { double }

          before do
            allow(subject).to receive(:kinesis_adapter).and_return kinesis_adapter
          end

          context 'when kinesis is enabled' do
            before { subject.enable }

            context 'when there is at least one job already running' do
              before { subject.stub(:job_running?).and_return true }

              it 'does not flush the pending events' do
                expect(kinesis_adapter).not_to receive(:flush)
                subject.flush_pending_events
              end
            end

            context 'when there are not any jobs running' do
              before { subject.stub(:job_running?).and_return false }

              it 'flushes the pending events' do
                expect(kinesis_adapter).to receive(:flush)
                subject.flush_pending_events
              end
            end
          end

          context 'when kinesis is disabled' do
            before { subject.disable }

            it 'does not flush the pending events' do
              expect(kinesis_adapter).not_to receive(:flush)
              subject.flush_pending_events
            end
          end
        end
      end
    end
  end
end
