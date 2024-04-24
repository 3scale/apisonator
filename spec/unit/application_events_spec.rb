require 'timecop'

module ThreeScale
  module Backend
    describe ApplicationEvents do
      describe '.generate' do
        context "when there aren't applications" do
          subject { ApplicationEvents.generate(applications) }

          context 'with empty array' do
            let(:applications) { [] }
            it { expect(subject).to be nil }
          end

          context 'with nil value' do
            let(:applications) { nil }
            it { expect(subject).to be nil }
          end
        end

        context 'when application has traffic for first time' do
          subject { ApplicationEvents.generate([application]) }
          let(:application) { { service_id: 3, application_id: 5 } }
          let(:event_types) { [:first_traffic, :first_daily_traffic] }
          let(:event)       { application.merge(timestamp: Time.now.utc.to_s) }

          before do
            Timecop.freeze(Time.now)
            event_types.each do |event_type|
              expect(EventStorage).to receive(:store).with(event_type, event)
            end
          end

          after do
            Timecop.return
          end

          it { expect(subject) }
        end

        context 'when application had has traffic for first time' do
          subject { ApplicationEvents.generate([application]) }
          let(:application) { { service_id: 3, application_id: 5 } }
          let(:current_time) { Time.now.utc }

          before do
            Timecop.travel(current_time - 24*60*60) do
              ApplicationEvents.generate([application])
            end
          end

          context 'with daily traffic for first time' do
            let(:event) { application.merge(timestamp: current_time.to_s) }

            before do
              expect(EventStorage).to_not receive(:store).with(:first_traffic, event)
              expect(EventStorage).to receive(:store).with(:first_daily_traffic, event)
              # ensure correct memoizer behaviour
              expect(Storage.instance)
                  .to receive(:incr)
                  .and_call_original
            end

            it { Timecop.freeze(current_time) { expect(subject) } }
          end

          context 'with daily traffic for second time' do
            before do
              ApplicationEvents.generate([application])
              expect(EventStorage).to_not receive(:store)
              # ensure correct memoizer behaviour
              expect(Storage.instance).to_not receive(:incr)
            end

            it { expect(subject) }
          end
        end
      end

      describe '.ping' do
        context 'when pinging works' do
          before do
            allow(EventStorage).to receive(:ping_if_not_empty).and_return(true)
          end

          it 'calls EventStorage.ping_if_not_empty' do
            expect(EventStorage).to receive(:ping_if_not_empty)
            described_class.ping
          end

          it 'returns true' do
            expect(described_class.ping).to be true
          end
        end

        context 'when pinging fails' do
          before do
            allow(EventStorage).to receive(:ping_if_not_empty).and_raise(StandardError)
          end

          it 'calls EventStorage.ping_if_not_empty' do
            expect(EventStorage).to receive(:ping_if_not_empty)
            described_class.ping rescue nil
          end

          it 'raises PingFailed' do
            expect { described_class.ping }.to raise_error(described_class::PingFailed)
          end
        end
      end
    end
  end
end
