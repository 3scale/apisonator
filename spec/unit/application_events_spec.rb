require_relative '../spec_helper'
require 'timecop'

module ThreeScale
  module Backend
    describe ApplicationEvents do
      describe '.generate' do
        context "when there aren't applications" do
          let(:applications) { [] }
          subject { ApplicationEvents.generate(applications) }

          it { expect(subject).to eq([]) }
        end

        context 'when application has traffic for first time' do
          let(:applications) do
            (1..3).map do |app_id|
              { service_id: 3, application_id: app_id, timestamp: Time.now.utc.to_s }
            end
          end
          let(:event_types)  { [:first_traffic] }

          subject { ApplicationEvents.generate(applications) }

          before do
            Timecop.freeze(Time.now)
            applications.each do |event|
              event_types.each do |event_type|
                expect(EventStorage).to receive(:store).with(event_type, event)
              end
            end
          end

          after do
            Timecop.return
          end

          it { expect(subject) }
        end

        context 'when application has traffic for first time in the day' do
          let(:applications) { }
          let(:event_type)   { :first_daily_traffic }
          let(:event)        { { } }

          before do
            expect(EventStorage).to receive(:store).with(event_type, event)
          end
        end
      end

      describe '.ping' do
        before { expect(EventStorage).to receive(:ping_if_not_empty) }
        it { expect(ApplicationEvents.ping).to be_true}
      end
    end
  end
end
