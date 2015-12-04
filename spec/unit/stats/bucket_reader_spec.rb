require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/bucket_reader'

module ThreeScale
  module Backend
    module Stats
      describe BucketReader.const_get(:LatestBucketReadMarker) do
        let(:bucket_create_interval) { 10 }
        let(:storage) { ThreeScale::Backend::Storage.instance }

        subject { described_class.new(storage) }

        describe '#latest_bucket_read= and #latest_bucket_read' do
          let (:bucket_name) { '20150101000000' }

          it 'the latest_bucket_read can be read after being set' do
            subject.latest_bucket_read = bucket_name
            expect(subject.latest_bucket_read).to eq bucket_name
          end
        end

        describe '#all_buckets' do
          context 'when there are not any buckets' do
            it 'returns empty' do
              expect(subject.all_buckets).to be_empty
            end
          end

          context 'when there are some buckets' do
            let(:first_bucket_saved) { '20150101000000' }
            let(:buckets) do
              [first_bucket_saved,
               (first_bucket_saved.to_i + bucket_create_interval).to_s]
            end
            before do
              buckets.each do |bucket|
                # It would be nice to have a class responsible for storing
                # buckets so we do not have to access 'storage' directly.
                storage.zadd(Keys.changed_keys_key, bucket.to_i, bucket)
              end
            end

            it 'returns the buckets' do
              expect(subject.all_buckets).to eq buckets
            end
          end
        end
      end

      describe BucketReader do
        let(:bucket_create_interval) { 10 }
        let(:storage) { ThreeScale::Backend::Storage.instance }
        let(:first_bucket_saved) { '20150101000000' }
        let(:buckets) do
          # Careful here if you add more. The name of the bucket is a
          # timestamp, so it is not enough to always add
          # bucket_create_interval. Remember to apply mod 60.
          [first_bucket_saved,
           (first_bucket_saved.to_i + bucket_create_interval).to_s,
           (first_bucket_saved.to_i + 2*bucket_create_interval).to_s]
        end

        subject { described_class.new(bucket_create_interval, storage) }

        let(:last_bucket_read_marker) { subject.send(:latest_bucket_read_marker) }

        describe '#pending_buckets' do
          let(:test_time) { DateTime.parse(buckets.last).to_time.utc }

          context 'when we have not read any buckets' do
            context 'when there are no buckets' do
              it 'returns an empty array' do
                expect(subject.pending_buckets.to_a).to be_empty
              end
            end

            context 'when there are some buckets' do
              before do
                buckets.each do |bucket|
                  storage.zadd(Keys.changed_keys_key, bucket.to_i, bucket)
                end
              end

              it 'returns all the buckets' do
                expect(subject.pending_buckets.to_a).to eq buckets
              end
            end
          end

          context 'when we have read some buckets' do
            let (:buckets_read) { 1 }
            let (:latest_bucket_read) { buckets[buckets_read - 1] }

            before do
              last_bucket_read_marker.latest_bucket_read = latest_bucket_read
            end

            it 'returns only the buckets that we have not read yet' do
              pending_buckets = subject.pending_buckets(test_time)
              expect(pending_buckets.to_a).to eq buckets[buckets_read..-1]
            end
          end

          context 'when latest_bucket_read has a name that belongs to a future timestamp' do
            let (:latest_bucket_read) do
              (buckets.last.to_i + bucket_create_interval).to_s
            end

            before do
              last_bucket_read_marker.latest_bucket_read = latest_bucket_read
            end

            it 'returns an empty list' do
              expect(subject.pending_buckets(test_time).to_a).to be_empty
            end
          end
        end
      end
    end
  end
end
