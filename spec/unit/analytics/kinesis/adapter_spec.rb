require_relative '../../../spec_helper'

module ThreeScale
  module Backend
    module Analytics
      describe KinesisAdapter do
        # EVENTS_PER_RECORD is set to a value optimized for running in
        # production. The tests run very slow if we use the same value.
        # Moreover, there is no benefit in using a big value that constant
        # when testing. For that reason, we modify its value and the constant
        # that depends on it before running these tests, and restore the
        # original values at the end.

        original_events_per_record = described_class.const_get(:EVENTS_PER_RECORD)
        original_events_per_batch =
            original_events_per_record*described_class.const_get(:MAX_RECORDS_PER_BATCH)

        tests_events_per_record = 10
        tests_events_per_batch =
            tests_events_per_record*described_class.const_get(:MAX_RECORDS_PER_BATCH)

        before(:all) do
          described_class.send(:remove_const, :EVENTS_PER_RECORD)
          described_class.const_set(:EVENTS_PER_RECORD, tests_events_per_record)

          described_class.send(:remove_const, :EVENTS_PER_BATCH)
          described_class.const_set(:EVENTS_PER_BATCH, tests_events_per_batch)
        end

        after(:all) do
          described_class.send(:remove_const, :EVENTS_PER_RECORD)
          described_class.const_set(:EVENTS_PER_RECORD, original_events_per_record)

          described_class.send(:remove_const, :EVENTS_PER_BATCH)
          described_class.const_set(:EVENTS_PER_BATCH, original_events_per_batch)
        end

        let(:kinesis_client) { double }
        let(:stream_name) { 'backend_stream' }
        let(:storage) { Backend::Storage.instance }
        let(:stats_storage) { Backend::Stats::Storage }
        let(:events_per_record) { described_class.const_get(:EVENTS_PER_RECORD) }
        let(:max_records_per_batch) { described_class.const_get(:MAX_RECORDS_PER_BATCH) }
        let(:pending_events_key) do
          described_class.const_get(:KINESIS_PENDING_EVENTS_KEY)
        end

        subject { described_class.new(stream_name, kinesis_client, storage) }

        describe '#send_events' do
          context 'when the number of events is smaller than the number of events per record' do
            let(:events) { generate_unique_events(events_per_record - 1) }

            it 'does not send the events to Kinesis' do
              expect(kinesis_client).not_to receive(:put_record_batch)
              subject.send_events(events)
            end

            it 'adds the events as pending events' do
              subject.send_events(events)
              expect(subject.send(:stored_pending_events)).to match_array events
            end
          end

          context 'when the number of events is enough to fill just 1 record' do
            let(:events) { generate_unique_events(events_per_record) }
            let(:events_pseudo_json) { subject.send(:events_to_pseudo_json, events) }

            before do
              allow(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: [{ data: events_pseudo_json }] })
                          .and_return(failed_put_count: 0,
                                      request_responses: [{ record_id: 'id' }])
            end

            it 'sends the events to Kinesis' do
              expect(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: [{ data: events_pseudo_json }] })
                          .once

              subject.send_events(events)
            end

            it 'leaves pending events empty' do
              subject.send_events(events)
              expect(subject.send(:stored_pending_events)).to be_empty
            end
          end

          context 'when the number of events fills several records but can be sent in 1 batch' do
            let(:records) { 2 } # Assuming that a batch can contain at least 2 records
            let(:events) { generate_unique_events(records*events_per_record) }
            let(:kinesis_records) do
              [{ data: subject.send(:events_to_pseudo_json,
                                    events[0..events_per_record - 1]) },
               { data: subject.send(:events_to_pseudo_json,
                                    events[events_per_record..-1]) }]
            end

            before do
              allow(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: kinesis_records })
                          .and_return(failed_put_count: 0,
                                      request_responses: Array.new(records, { record_id: 'id' }))
            end

            it 'sends the events to Kinesis' do
              expect(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: kinesis_records })
                          .once

              subject.send_events(events)
            end

            it 'leaves pending events empty' do
              subject.send_events(events)
              expect(subject.send(:stored_pending_events)).to be_empty
            end
          end

          context 'when the number of events is too big to be sent in just one batch' do
            let(:records) { max_records_per_batch + 1 } # Can be sent in 2 batches
            let(:events) { generate_unique_events(records*events_per_record) }
            let(:kinesis_records) do
              events.each_slice(events_per_record).map do |events_slice|
                { data: subject.send(:events_to_pseudo_json, events_slice) }
              end
            end

            let(:records_first_batch) { kinesis_records.take(max_records_per_batch) }
            let(:records_second_batch) { [kinesis_records.last] }

            before do
              # First batch
              allow(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: records_first_batch })
                          .and_return(failed_put_count: 0,
                                      request_responses: Array.new(max_records_per_batch,
                                                                   { record_id: 'id' }))

              # Second batch
              allow(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: records_second_batch })
                          .and_return(failed_put_count: 0,
                                      request_responses: Array.new(1, { record_id: 'id' }))
            end

            it 'sends the events to Kinesis' do
              expect(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: records_first_batch })
                          .once

              expect(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: records_second_batch })
                          .once

              subject.send_events(events)
            end

            it 'leaves pending events empty' do
              subject.send_events(events)
              expect(subject.send(:stored_pending_events)).to be_empty
            end
          end

          context 'when Kinesis returns an error for some record' do
            let(:events) { generate_unique_events(2*events_per_record) }
            let(:events_first_record) { events[0..events_per_record - 1] }
            let(:events_second_record) { events[events_per_record..-1] }
            let(:kinesis_first_record) do
              subject.send(:events_to_pseudo_json, events_first_record)
            end
            let(:kinesis_second_record) do
              subject.send(:events_to_pseudo_json, events_second_record)
            end

            before do
              # return error for the second record
              allow(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: [{ data: kinesis_first_record },
                                            { data: kinesis_second_record }] })
                          .and_return(failed_put_count: 1,
                                      request_responses: [{ record_id: 'id' },
                                                          { error_code: 'err' }])
            end

            it 'marks the events of the failed record as pending events' do
              subject.send_events(events_first_record + events_second_record)
              expect(subject.send(:stored_pending_events))
                  .to match_array events_second_record
            end
          end

          context 'when the Kinesis client raises an exception in some batch' do
            let(:records) { max_records_per_batch + 1 } # Can be sent in 2 batches
            let(:events) { generate_unique_events(records*events_per_record) }
            let(:events_second_batch) do
              events[events_per_record*max_records_per_batch..-1]
            end
            let(:kinesis_records) do
              events.each_slice(events_per_record).map do |events_slice|
                { data: subject.send(:events_to_pseudo_json, events_slice) }
              end
            end

            let(:records_first_batch) { kinesis_records.take(max_records_per_batch) }
            let(:records_second_batch) { [kinesis_records.last] }

            before do
              # First batch
              allow(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: records_first_batch })
                          .and_return(failed_put_count: 0,
                                      request_responses: Array.new(max_records_per_batch,
                                                                   { record_id: 'id' }))

              # Second batch
              allow(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: records_second_batch })
                          .and_raise(Aws::Firehose::Errors::LimitExceededException.new(nil, nil))
            end

            it 'marks the events of the failed batch as pending events' do
              subject.send_events(events)
              expect(subject.send(:stored_pending_events))
                  .to match_array events_second_batch
            end
          end

          context 'when the limit of pending events has been reached' do
            let(:events) { [] } # Does not matter, because the stubbing in the before clause
            let(:limit_reached_msg) do
              described_class.const_get(:MAX_PENDING_EVENTS_REACHED_MSG)
            end

            before do
              allow(subject).to receive(:limit_pending_events_reached?).and_return true
            end

            context 'and bucket storage is enabled' do
              before { stats_storage.enable! }

              it 'disables bucket storage indicating emergency' do
                subject.send_events(events)
                Memoizer.reset!

                expect(stats_storage.enabled?).to be false
                expect(stats_storage.last_disable_was_emergency?).to be true
              end

              it 'logs a message' do
                expect(Backend.logger).to receive(:info).with(limit_reached_msg)
                subject.send_events(events)
              end
            end

            context 'and bucket storage is not enabled' do
              before { stats_storage.disable! }

              it 'does not mark that bucket storage was disabled because of an emergency' do
                subject.send_events(events)
                Memoizer.reset!

                expect(stats_storage.enabled?).to be false
                expect(stats_storage.last_disable_was_emergency?).to be false
              end

              it 'does not log a message' do
                expect(Backend.logger).not_to receive(:info)
                subject.send_events(events)
              end
            end
          end

          context 'when the number of pending events has not been reached' do
            let(:events) { [] } # Does not matter, because the stubbing in the before clause

            before do
              allow(subject).to receive(:limit_pending_events_reached?).and_return false
            end

            it 'does not disable bucket creation' do
              expect(stats_storage).not_to receive(:disable!)
              subject.send_events(events)
            end
          end
        end

        describe '#flush' do
          context 'when the number of pending events is not enough to fill 1 record' do
            let(:events) { generate_unique_events(events_per_record - 1) }
            let(:events_pseudo_json) { subject.send(:events_to_pseudo_json, events) }

            before do
              allow(subject).to receive(:stored_pending_events).and_return(events)

              allow(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: [{ data: events_pseudo_json }] })
                          .and_return(failed_put_count: 0,
                                      request_responses: [{ record_id: 'id' }])
            end

            it 'sends the events to Kinesis' do
              expect(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: [{ data: events_pseudo_json }] })
                          .once

              subject.flush
            end

            it 'returns the number of events sent' do
              expect(subject.flush).to eq events.size
            end

            it 'leaves pending events empty' do
              subject.flush
              expect(storage.smembers(pending_events_key)).to be_empty
            end
          end

          context 'when the number of pending events is enough to fill 1 record' do
            let(:events) { generate_unique_events(events_per_record) }
            let(:events_pseudo_json) { subject.send(:events_to_pseudo_json, events) }

            before do
              allow(subject).to receive(:stored_pending_events).and_return(events)

              allow(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: [{ data: events_pseudo_json }] })
                          .and_return(failed_put_count: 0,
                                      request_responses: [{ record_id: 'id' }])
            end

            it 'sends the events to Kinesis' do
              expect(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: [{ data: events_pseudo_json }] })
                          .once

              subject.flush
            end

            it 'returns the number of events sent' do
              expect(subject.flush).to eq events.size
            end

            it 'leaves pending events empty' do
              subject.flush
              expect(storage.smembers(pending_events_key)).to be_empty
            end
          end

          context 'when there are no pending events' do
            it 'does not send the events to Kinesis' do
              expect(kinesis_client).not_to receive(:put_record_batch)
              subject.flush
            end

            it 'returns 0' do
              expect(subject.flush).to be_zero
            end

            it 'leaves pending events empty' do
              subject.flush
              expect(storage.smembers(pending_events_key)).to be_empty
            end
          end

          context 'when limit > 0' do
            let(:n_events) { 2 }
            let(:events) { generate_unique_events(n_events) }

            before do
              allow(subject).to receive(:stored_pending_events).and_return(events)
            end

            context 'and greater than the number of events to be sent' do
              let(:limit) { events.size + 1 }
              let(:events_pseudo_json) { subject.send(:events_to_pseudo_json, events) }

              before do
                allow(kinesis_client)
                    .to receive(:put_record_batch)
                            .with({ delivery_stream_name: stream_name,
                                    records: [{ data: events_pseudo_json }] })
                            .and_return(failed_put_count: 0,
                                        request_responses: [{ record_id: 'id' }])
              end

              it 'sends to Kinesis all the events' do
                expect(kinesis_client)
                    .to receive(:put_record_batch)
                            .with({ delivery_stream_name: stream_name,
                                    records: [{ data: events_pseudo_json }] })
                            .once

                subject.flush(limit)
              end

              it 'returns the number of events sent' do
                expect(subject.flush(limit)).to eq [limit, n_events].min
              end

              it 'leaves pending events empty' do
                subject.flush(limit)
                expect(storage.smembers(pending_events_key)).to be_empty
              end
            end

            context 'and lesser than the number of events to be sent' do
              let(:limit) { events.size - 1 }
              let(:events_pseudo_json) do
                subject.send(:events_to_pseudo_json, events.take(limit))
              end

              before do
                allow(kinesis_client)
                    .to receive(:put_record_batch)
                            .with({ delivery_stream_name: stream_name,
                                    records: [{ data: events_pseudo_json }] })
                            .and_return(failed_put_count: 0,
                                        request_responses: [{ record_id: 'id' }])
              end

              it 'sends to Kinesis only the number of events specified in the limit' do
                expect(kinesis_client)
                    .to receive(:put_record_batch)
                            .with({ delivery_stream_name: stream_name,
                                    records: [{ data: events_pseudo_json }] })
                            .once

                subject.flush(limit)
              end

              it 'returns the number of events sent' do
                expect(subject.flush(limit)).to eq [limit, n_events].min
              end

              it 'marks the events that have not been flushed as pending events' do
                subject.flush(limit)
                expect(storage.smembers(pending_events_key).size)
                    .to eq events.size - limit
              end
            end

            context 'and sending a batch to kinesis fails' do
              let(:limit) { events.size - 1 }
              let(:events_pseudo_json) do
                subject.send(:events_to_pseudo_json, events.take(limit))
              end

              before do
                allow(kinesis_client)
                    .to receive(:put_record_batch)
                            .with({ delivery_stream_name: stream_name,
                                    records: [{ data: events_pseudo_json }] })
                            .and_return(failed_put_count: 1,
                                        request_responses: [{ record_id: 'id' },
                                                            { error_code: 'err' }])
              end

              it 'sends to Kinesis only the number of events specified in the limit' do
                expect(kinesis_client)
                    .to receive(:put_record_batch)
                            .with({ delivery_stream_name: stream_name,
                                    records: [{ data: events_pseudo_json }] })
                            .once

                subject.flush(limit)
              end

              it 'returns 0' do
                expect(subject.flush(limit)).to be_zero
              end

              it 'marks the events that have not been flushed as pending events' do
                subject.flush(limit)
                expect(storage.smembers(pending_events_key).size).to eq events.size
              end

            end
          end

          context 'when limit < 0' do
            let(:limit) { -1 }
            let(:events) { generate_unique_events(1) }

            it 'raises an ArgumentError' do
              expect { subject.flush(limit) }.to raise_error ArgumentError
            end
          end
        end

        describe '#num_pending_events' do
          context 'when there are no pending events' do
            it 'returns 0' do
              expect(subject.num_pending_events).to be_zero
            end
          end

          context 'when there are some pending events' do
            let(:num_events) { 2 }
            let(:events) { generate_unique_events(num_events) }

            before { subject.send(:store_pending_events, events) }

            it 'returns the number of pending events' do
              expect(subject.num_pending_events).to eq num_events
            end
          end
        end

        # The events that we use in these tests need to be unique. Using
        # identical events has undesirable effects. For example, Redis stores
        # failed events in a set. If we generate N unique events and all of
        # them fail, we will find N events in the failed events set of Redis,
        # as we would expect. However, if we send N identical events, we will
        # just find one in Redis.
        def generate_unique_events(n_events)
          (1..n_events).map do |i|
            { service: 's', metric: 'm', period: 'year', timestamp: '20150101', value: i }
          end
        end
      end
    end
  end
end
