require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/bucket_reader'

module ThreeScale
  module Backend
    module Stats
      describe BucketReader.const_get(:LatestBucketReadMarker) do
        let(:storage) { ThreeScale::Backend::Storage.instance }

        subject { described_class.new(storage) }

        describe '#latest_bucket_read' do
          context 'when the latest bucket read has not been set' do
            it 'returns nil' do
              expect(subject.latest_bucket_read).to be_nil
            end
          end

          context 'when the latest bucket read has been set' do
            let (:bucket_name) { '20150101000000' }
            before { subject.latest_bucket_read = bucket_name }

            it 'returns the latest bucket read' do
              expect(subject.latest_bucket_read).to eq bucket_name
            end
          end
        end
      end

      describe BucketReader do
        let(:bucket_create_interval) { 10 }
        let(:storage) { ThreeScale::Backend::Storage.instance }
        let(:bucket_storage) { BucketStorage.new(storage) }

        # Careful here if you add more. The name of the bucket is a
        # timestamp, so it is not enough to always add
        # bucket_create_interval. Remember to apply mod 60.
        let(:first_bucket) { '20150101000000' }
        let(:second_bucket) { (first_bucket.to_i + bucket_create_interval).to_s }
        let(:third_bucket) { (first_bucket.to_i + 2*bucket_create_interval).to_s }

        let(:buckets_and_events) do
          { first_bucket => { 'event11' => 'value11',
                              'event12' => 'value12' },
            second_bucket =>  { 'event21' => 'value21',
                                'event22' => 'value22' },
            third_bucket => { 'event31' => 'value31',
                              'event32' => 'value32' } }
        end

        let(:current_time) { DateTime.parse(third_bucket).to_time.utc }

        subject { described_class.new(bucket_create_interval, bucket_storage, storage) }

        let(:last_bucket_read_marker) { subject.send(:latest_bucket_read_marker) }

        it 'raises InvalidInterval when bucket_create_interval is negative' do
          expect{described_class.new(-1, bucket_storage, storage)}
            .to raise_error(BucketReader::InvalidInterval)
        end

        it 'raises InvalidInterval when bucket_create_interval does not divide 60' do
          expect{described_class.new(90, bucket_storage, storage)}
            .to raise_error(BucketReader::InvalidInterval)
        end

        describe '#pending_events_in_buckets' do
          context 'when we have not read any buckets' do
            context 'when there are no buckets' do
              it 'returns an empty hash' do
                expect(subject.pending_events_in_buckets(current_time)).to be_empty
              end
            end

            context 'when there are some buckets' do
              before { save_buckets_and_events(buckets_and_events) }

              it 'returns all the events in the buckets' do
                expect(subject.pending_events_in_buckets(current_time))
                    .to eq buckets_and_events.values.reduce(&:merge)
              end
            end
          end

          context 'when we have read some buckets' do
            let (:latest_bucket_read) { first_bucket }
            
            before do
              save_buckets_and_events(buckets_and_events)
              last_bucket_read_marker.latest_bucket_read = latest_bucket_read
            end

            it 'returns the events of the buckets that we have not read yet' do
              expect(subject.pending_events_in_buckets(current_time))
                  .to eq (buckets_and_events[second_bucket]
                              .merge(buckets_and_events[third_bucket]))
            end
          end

          context 'when latest_bucket_read has a name that belongs to a future timestamp' do
            let (:latest_bucket_read) do
              (third_bucket.to_i + bucket_create_interval).to_s
            end

            before { last_bucket_read_marker.latest_bucket_read = latest_bucket_read }

            it 'returns an empty hash' do
              expect(subject.pending_events_in_buckets(current_time)).to be_empty
            end
          end

          context 'when some of the pending buckets contain repeated keys' do
            let(:older_bucket) { first_bucket }
            let(:newer_bucket) { second_bucket }
            let(:buckets_and_events) do
              { older_bucket => { 'event11' => '10', 'event12' => '30' },
                newer_bucket => { 'event11' => '20', 'event13' => '40' } }
            end

            before { save_buckets_and_events(buckets_and_events) }

            it 'returns the events with their latest values' do
              expect(subject.pending_events_in_buckets(current_time))
                  .to eq (buckets_and_events[older_bucket]
                              .merge(buckets_and_events[newer_bucket]))
            end
          end
        end

        def save_buckets_and_events(buckets_and_events)
          buckets_and_events.each do |bucket, events|
            events.each do |event_key, event_value|
              bucket_storage.put_in_bucket(event_key, bucket)
              storage.set(event_key, event_value)
            end
          end
        end
      end
    end
  end
end
