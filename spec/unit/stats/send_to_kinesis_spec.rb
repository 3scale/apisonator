require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/send_to_kinesis'

module ThreeScale
  module Backend
    module Stats
      describe SendToKinesis do
        subject { SendToKinesis }

        before { expect(subject.enabled?).to be_false }

        describe '.enable' do
          it 'makes .enabled? return true' do
            subject.enable
            expect(subject.enabled?).to be_true
          end
        end

        describe '.disable' do
          before { subject.enable }

          it 'makes .enabled? return false' do
            subject.disable
            expect(subject.enabled?).to be_false
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
            it 'does not schedule a kinesis job' do
              expect(Resque).not_to receive(:enqueue)
              subject.schedule_job
            end
          end
        end
      end
    end
  end
end
