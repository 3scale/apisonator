require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/kinesis_adapter'

module ThreeScale
  module Backend
    module Stats
      describe KinesisAdapter do
        let(:kinesis_client) { double }
        let(:stream_name) { 'backend_stream' }

        subject { described_class.new(stream_name, kinesis_client) }

        describe '#send_events' do
          let(:record_size) { described_class.const_get(:MAX_RECORD_SIZE_BYTES) }

          context 'size of events is bigger than the size of a single record' do
            # Prepare the data so we get 2 groups of records: the first with 2
            # events and the second with 1.

            # 2 services of 'record_size' would not fit in a record, because of
            # the json overhead. That is why I multiply by a constant.
            let(:event) { { service: '0'*((record_size/2)*0.8) } }
            let(:events) { Array.new(3, event) }

            before do
              expect(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: [{ data: Array.new(2, event).to_json },
                                            { data: [event].to_json }] })
            end

            it 'sends the events in well-constructed records' do
              subject.send_events(events)
            end
          end

          context 'size of events is smaller than the size of a single record' do
            let(:events) do
              [{ service: 's', metric: 'm', period: 'year', year: '2015' }]
            end

            before { expect(kinesis_client).not_to receive(:put_record_batch) }

            it 'does not send the events' do
              subject.send_events(events)
            end
          end
        end
      end
    end
  end
end
