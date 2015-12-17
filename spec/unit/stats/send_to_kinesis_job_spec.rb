require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/send_to_kinesis_job'

module ThreeScale
  module Backend
    module Stats
      describe SendToKinesisJob do
        let(:end_time_utc) { Time.now.utc }
        let(:bucket_reader) { double }
        let(:kinesis_adapter) { double }

        subject { SendToKinesisJob }

        describe '.perform_logged' do
          context 'when there are pending events' do
            let(:pending_events) do
              { 'stats/{service:s1}/metric:m1/day:20151210' => '10',
                'stats/{service:s1}/metric:m1/day:20151211' => '20' }
            end
            let(:bucket) { '20150101000000' }

            before do
              # I use a mock for the bucket reader because otherwise, I would
              # need to store buckets, the event keys, the value for each event,
              # etc. That would complicate this test a lot and would duplicate
              # work already done in the BucketReader tests.
              allow(bucket_reader)
                  .to receive(:pending_events_in_buckets)
                          .with(end_time_utc)
                          .and_return({ events: pending_events, latest_bucket: bucket })

              allow(bucket_reader)
                  .to receive(:latest_bucket_read=).with(bucket)

              allow(kinesis_adapter).to receive(:send_events)
            end

            it 'returns array with format [true, msg]' do
              expect(subject.perform_logged(end_time_utc, bucket_reader, kinesis_adapter))
                  .to eq [true, subject.send(:msg_events_sent, pending_events.size)]
            end
          end

          context 'when there are not any pending events' do
            before do
              allow(bucket_reader)
                  .to receive(:pending_events_in_buckets)
                          .with(end_time_utc)
                          .and_return({ events: { }, latest_bucket: nil })
            end

            it 'does not send anything to the kinesis adapter' do
              expect(kinesis_adapter).not_to receive(:send_events)
              subject.perform_logged(end_time_utc, bucket_reader, kinesis_adapter)
            end

            it 'does not mark any bucket as the latest read' do
              expect(bucket_reader).not_to receive(:latest_bucket_read=)
              subject.perform_logged(end_time_utc, bucket_reader, kinesis_adapter)
            end

            it 'returns array with format [true, msg]' do
              expect(subject.perform_logged(end_time_utc, bucket_reader, kinesis_adapter))
                  .to eq [true, subject.send(:msg_events_sent, 0)]
            end
          end
        end
      end
    end
  end
end
