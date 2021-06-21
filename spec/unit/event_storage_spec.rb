require 'pry'
module ThreeScale
  module Backend
    describe EventStorage do
      describe '.store' do
        context 'with valid event type' do
          it 'returns ok' do
            expect(EventStorage.store(:alert, {})).to be true
            expect(EventStorage.store(:first_traffic, {})).to be true
          end

          context 'when event already exists' do
            let(:event) { { id: 3, service_id: 10, timestamp: Time.now.utc} }

            before { EventStorage.store(:alert, event) }

            it 'returns ok' do
              expect(EventStorage.store(:alert, event)).to be true
            end

            it 'modifies the size of events set' do
              current_size = EventStorage.size
              EventStorage.store(:alert, event)
              expect(EventStorage.size).to be(current_size + 1)
            end
          end
        end

        context 'with invalid event type' do
          it 'raises an exception' do
            expect { EventStorage.store(:foo, {}) }.to raise_error(InvalidEventType)
          end
        end
      end

      describe '.list' do
        context 'with events in set' do
          let(:num_events) { 3 }
          let(:event_type) { :alert }
          before do
            num_events.times do
              EventStorage.store(event_type, { timestamp: Time.now })
            end
          end

          it 'returns all stored events' do
            expect(EventStorage.list.size).to be(num_events)
          end

          it 'returns events ordered by id' do
            expect(EventStorage.list.map { |event| event[:id] }).to eq([1,2,3])
          end

          it 'decodes events' do
            event = EventStorage.list.first
            event.keys.map { |key| expect(key).to be_a(Symbol) }
            event[:object].keys.map { |key| expect(key).to be_a(Symbol) }

            expect(event[:type]).to eq(event_type.to_s)
            expect(event[:object][:timestamp]).to be_a(Time)
          end
        end

        context 'without events in set' do
          subject { EventStorage.list }

          it { expect(subject).to be_empty }
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

      describe '.ping_if_not_empty' do
        before do
          allow(EventStorage).to receive(:events_hook).and_return("foo")
          allow(Net::HTTP).to receive(:post_form).and_return(true)
        end

        context 'with events in set' do
          subject { EventStorage.ping_if_not_empty }

          before do
            3.times { EventStorage.store(:alert, {}) }
          end

          context 'when a ping was executed previously' do
            context 'and ping TTL is expired' do
              before do
                EventStorage.ping_if_not_empty

                # Simulate expired TTL
                EventStorage.send(:storage).del(EventStorage.send(:events_ping_key))
              end

              it { expect(subject).to be true }
            end

            context 'and ping TTL is not expired' do
              before do
                stub_const("ThreeScale::Backend::EventStorage::PING_TTL", 1000)
                EventStorage.ping_if_not_empty
              end

              it { expect(subject).to be_falsey }
            end
          end

          context 'with multiple calls at the same moment (race condition)' do
            it 'returns falsey except for one successful case' do
              # This test does not work when using the async storage. The async
              # libs run async tasks inside Fibers and creating threads like in
              # this test
              unless ThreeScale::Backend.configuration.redis.async
                num_threads = 4

                threads = num_threads.times.map do
                  Thread.new { Thread.stop; EventStorage.ping_if_not_empty }
                end

                values = threads.each do |t|
                  sleep 0.01 until t.stop?
                end
                  .map(&:wakeup)
                  .map(&:value)

                expect(values).to match_array([true] + [nil] * (num_threads - 1))
              end
            end
          end

          context 'when there is no event_hook present' do
            before do
              allow(EventStorage).to receive(:events_hook).and_return(false)
            end

            it { expect(subject).to be_falsey }
          end

          context 'when hook notification fails' do
            before do
              allow(Net::HTTP).to receive(:post_form).and_raise(StandardError)
            end

            subject { EventStorage }

            it 'raises an error' do
              expect { subject.ping_if_not_empty }.to raise_error(StandardError)
            end
          end
        end

        context 'without events in set' do
          subject { EventStorage }

          it 'returns falsey' do
            expect(subject.ping_if_not_empty).to be_falsey
          end
        end
      end
    end
  end
end
