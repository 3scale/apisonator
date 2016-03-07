require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module Stats
      describe RedshiftImporter do
        subject { described_class }

        describe '.schedule_job' do
          context 'when the importer is enabled' do
            context 'and backend is running in production' do
              before do
                allow(Backend).to receive(:production?).and_return true
                subject.enable
              end

              it 'schedules a Redshift job' do
                expect(Resque).to receive(:enqueue)
                subject.schedule_job
              end
            end

            context 'and backend is not running in production' do
              before do
                allow(Backend).to receive(:production?).and_return false
                subject.enable
              end

              it 'does not schedule a Redshift job' do
                expect(Resque).not_to receive(:enqueue)
                subject.schedule_job
              end
            end
          end

          context 'when the importer is disabled' do
            before { subject.disable }

            it 'does not schedule a Redshift job' do
              expect(Resque).not_to receive(:enqueue)
              subject.schedule_job
            end
          end
        end

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
      end
    end
  end
end
