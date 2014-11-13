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
    end
  end
end
