require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/bucket_storage'

module ThreeScale
  module Backend
    module Stats
      describe BucketStorage do
        let(:storage) { ThreeScale::Backend::Storage.instance }
        let(:bucket) { '20150101000000' }
        let(:event_key) { 'stats/{service:11}/metric:21/day:20151207' }

        subject { described_class.new(storage) }

        describe '#delete_bucket' do
          context 'when the bucket exists' do
            before { subject.put_in_bucket(event_key, bucket) }

            it 'returns true' do
              expect(subject.delete_bucket(bucket)).to be_true
            end

            it 'deletes the bucket' do
              subject.delete_bucket(bucket)
              expect(subject.all_buckets).not_to include bucket
            end
          end

          context 'when the bucket does not exist' do
            let(:bucket) { 'invalid_bucket_name' }

            it 'returns false' do
              expect(subject.delete_bucket(bucket)).to be_false
            end
          end
        end

        describe '#delete_range' do
          let(:buckets) { %w(20150101000000 20150101000010 20150101000020 20150101000030) }

          before do
            buckets.each { |bucket| subject.put_in_bucket(event_key, bucket) }
          end

          context 'when the bucket exists' do
            context 'when it is the first one' do
              let(:bucket) { buckets.first }

              it 'only deletes the first one' do
                subject.delete_range(bucket)
                expect(subject.all_buckets).to match_array buckets[1..-1]
              end
            end

            context 'when it is the last one' do
              let(:bucket) { buckets.last }

              it 'deletes all the buckets' do
                subject.delete_range(bucket)
                expect(subject.all_buckets).to be_empty
              end
            end

            context 'when it is one in the middle' do
              let(:position) { 2 }
              let(:bucket) { buckets[position] }

              it 'deletes the bucket specified and all the previous ones' do
                subject.delete_range(bucket)
                expect(subject.all_buckets).to match_array buckets[(position + 1)..-1]
              end
            end
          end

          context 'when the bucket does not exist' do
            context 'when it is a bucket created before the first one that exists' do
              let (:bucket) { '20140101000000' }

              it 'does not delete any buckets' do
                subject.delete_range(bucket)
                expect(subject.all_buckets).to match_array buckets
              end
            end

            context 'when it is a bucket created after the last one that exists' do
              let (:bucket) { (buckets.last.to_i + 10).to_s }

              it 'deletes all the buckets' do
                subject.delete_range(bucket)
                expect(subject.all_buckets).to be_empty
              end
            end
          end
        end

        describe '#all_buckets' do
          context 'when there are no buckets' do
            it 'returns an empty list' do
              expect(subject.all_buckets).to be_empty
            end
          end

          context 'when there are some buckets' do
            let(:buckets) { %w(20150101000000 20150101000010) }

            before do
              buckets.each { |bucket| subject.put_in_bucket(event_key, bucket) }
            end

            it 'returns all the buckets' do
              expect(subject.all_buckets).to eq buckets
            end
          end
        end

        describe '#put_in_bucket' do
          let(:event_value) { 10 }

          before { storage.set(event_key, event_value) }

          context 'when the bucket exists' do
            it 'puts the event in the bucket' do
              subject.put_in_bucket(event_key, bucket)
              expect(subject.bucket_content_with_values(bucket))
                  .to eq ({ event_key => event_value })
            end
          end

          context 'when the bucket does not exist' do
            let(:new_bucket) { (bucket.to_i + 10).to_s }

            it 'creates the bucket' do
              subject.put_in_bucket(event_key, new_bucket)
              expect(subject.all_buckets).to include new_bucket
            end

            it 'puts the event in the bucket' do
              subject.put_in_bucket(event_key, new_bucket)
              expect(subject.bucket_content_with_values(new_bucket))
                  .to eq ({ event_key => event_value })
            end
          end
        end

        describe '#bucket_content_with_values' do
          context 'when the bucket exists' do
            let(:events) do
              { 'stats/{service:11}/metric:21/day:20151207' => 10,
                'stats/{service:12}/metric:22/day:20151208' => 20 }
            end

            before do
              events.each do |event_key, event_value|
                subject.put_in_bucket(event_key, bucket)
                storage.set(event_key, event_value)
              end
            end

            it 'returns a hash with the contents of the bucket and their values' do
              expect(subject.bucket_content_with_values(bucket)).to eq events
            end
          end

          context 'when the bucket does not exist' do
            let(:bucket) { 'invalid_bucket_name' }

            it 'returns an empty hash' do
              expect(subject.bucket_content_with_values(bucket)).to be_empty
            end
          end
        end
      end
    end
  end
end
