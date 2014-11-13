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

      describe '.delete' do
        before do
          3.times { EventStorage.store(:alert, {}) }
        end
        let(:event) { EventStorage.list.first }

        context 'with valid id' do
          subject { EventStorage.delete(event[:id]) }

          it { expect(subject).to be(1) }
          it 'modifies the size of events set' do
            expect(EventStorage.size).to be(3)
            EventStorage.delete(event[:id])
            expect(EventStorage.size).to be(2)
          end

          it 'is not in events set' do
            existing_ids = EventStorage.list.map { |e| e[:id] }
            expect(existing_ids).to include(event[:id])
            subject
            existing_ids = EventStorage.list.map { |e| e[:id] }
            expect(existing_ids).to_not include(event[:id])
          end

          context 'when the event was previously deleted' do
            before do
              EventStorage.delete(event[:id])
            end

            it { expect(subject).to be(0) }
            it 'not modify the size of events set' do
              expect(EventStorage.size).to be(2)
              EventStorage.delete(event[:id])
              expect(EventStorage.size).to be(2)
            end
          end
        end

        context 'with invalid id' do
          let(:ids) { [nil, -1, "foo"] }

          it 'returns the number of events removed' do
            ids.map { |id| expect(EventStorage.delete(id)).to be(0) }
          end
        end
      end

      describe '.delete_range' do
        before do
          3.times { EventStorage.store(:alert, {}) }
        end

        context 'with the id of last event in set' do
          let(:id) { EventStorage.list.last[:id] }

          it 'returns the number of events removed' do
            expect(EventStorage.delete_range(id)).to be(3)
          end

          it 'removes all events' do
            EventStorage.delete_range(id)
            expect(EventStorage.size).to be(0)
          end
        end

        context 'with the id of first event in set' do
          let(:id) { EventStorage.list.first[:id] }

          it 'returns the number of events removed' do
            expect(EventStorage.delete_range(id)).to be(1)
          end

          it 'removes just first event' do
            EventStorage.delete_range(id)
            expect(EventStorage.size).to be(2)
          end
        end

        context 'with invalid range' do
          let(:ranges) { [nil, -1, "foo"] }

          it 'returns the number of events removed' do
            ranges.map do |range_limit|
              expect(EventStorage.delete_range(range_limit)).to be(0)
            end
          end
        end
      end
    end
  end
end
