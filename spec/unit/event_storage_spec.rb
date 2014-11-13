module ThreeScale
  module Backend
    describe EventStorage do
      describe '.store' do
        context 'with valid event type' do
          it 'returns ok' do
            expect(EventStorage.store(:alert, {})).to be_true
            expect(EventStorage.store(:first_traffic, {})).to be_true
          end
        end

        context 'with invalid event type' do
          it 'raises an exception' do
            expect { EventStorage.store(:foo, {}) }.to raise_error
          end
        end
      end

      describe '.size' do
        subject { EventStorage.size }

        context 'with events' do
          let(:num_events) { 3 }
          before do
            num_events.times { EventStorage.store(:alert, {}) }
          end

          it { expect(subject).to be(num_events) }
        end

        context 'with no events' do
          it { expect(subject).to be(0) }
        end
      end
    end
  end
end
