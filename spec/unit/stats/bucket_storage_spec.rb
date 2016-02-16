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
              expect(subject.delete_bucket(bucket)).to be true
            end

            it 'deletes the bucket from the set' do
              subject.delete_bucket(bucket)
              expect(subject.all_buckets).not_to include bucket
            end

            it 'deletes the contents of the bucket' do
              subject.delete_bucket(bucket)
              expect(subject.buckets_content_with_values([bucket])).to be_empty
            end
          end

          context 'when the bucket does not exist' do
            let(:bucket) { 'invalid_bucket_name' }

            it 'returns false' do
              expect(subject.delete_bucket(bucket)).to be false
            end
          end
        end

        describe '#delete_range' do
          let(:buckets) { %w(20150101000000 20150101000010 20150101000020 20150101000030) }
          let(:event_keys) do # One event in each bucket
            ['stats/{service:11}/metric:21/day:20151207',
             'stats/{service:11}/metric:21/day:20151208',
             'stats/{service:11}/metric:21/day:20151209',
             'stats/{service:11}/metric:21/day:20151210']
          end

          before do
            buckets.each_with_index do |bucket, index|
              subject.put_in_bucket(event_keys[index], bucket)
            end
          end

          context 'when the bucket exists' do
            context 'when it is the first one' do
              let(:bucket) { buckets.first }

              it 'only deletes the first one from the set of buckets' do
                subject.delete_range(bucket)
                expect(subject.all_buckets).to match_array buckets[1..-1]
              end

              it 'only deletes the content of the first bucket' do
                subject.delete_range(bucket)
                expect(subject.buckets_content_with_values(buckets).keys)
                    .to match_array event_keys[1..-1]
              end
            end

            context 'when it is the last one' do
              let(:bucket) { buckets.last }

              it 'deletes all the buckets from the set of buckets' do
                subject.delete_range(bucket)
                expect(subject.all_buckets).to be_empty
              end

              it 'deletes the contents of all the buckets' do
                subject.delete_range(bucket)
                expect(subject.buckets_content_with_values(buckets)).to be_empty
              end
            end

            context 'when it is one in the middle' do
              let(:position) { 2 }
              let(:bucket) { buckets[position] }

              it 'deletes the bucket and the previous ones from the set of buckets' do
                subject.delete_range(bucket)
                expect(subject.all_buckets).to match_array buckets[(position + 1)..-1]
              end

              it 'deletes the contents of the given bucket and the previous ones' do
                subject.delete_range(bucket)
                expect(subject.buckets_content_with_values(buckets).keys)
                    .to match_array event_keys[(position + 1)..-1]
              end
            end
          end

          context 'when the bucket does not exist' do
            context 'and it has a name that says it was created before the first one that exists' do
              let (:bucket) { '20140101000000' }

              it 'does not delete any buckets' do
                subject.delete_range(bucket)
                expect(subject.all_buckets).to match_array buckets
              end
            end

            context 'and it has a name that says it was created after the last one that exists' do
              let (:bucket) { (buckets.last.to_i + 10).to_s }

              it 'deletes all the buckets from the set of buckets' do
                subject.delete_range(bucket)
                expect(subject.all_buckets).to be_empty
              end

              it 'deletes the contents of all the buckets' do
                subject.delete_range(bucket)
                expect(subject.buckets_content_with_values(buckets)).to be_empty
              end
            end
          end
        end

        describe '#delete_all_buckets_and_keys' do
          let(:buckets) { %w(20150101000000 20150101000010) }
          let(:event_keys) do # One event in each bucket
            ['stats/{service:11}/metric:21/day:20151207',
             'stats/{service:11}/metric:21/day:20151208']
          end

          before do
            buckets.each_with_index do |bucket, index|
              subject.put_in_bucket(event_keys[index], bucket)
            end
          end

          it 'disables the bucket storage' do
            Storage.enable!
            subject.delete_all_buckets_and_keys(silent: true)
            Memoizer.reset! # Needed because Storage.enabled? is memoized
            expect(Storage.enabled?).to be false
          end

          it 'deletes all the buckets from the set of buckets' do
            subject.delete_all_buckets_and_keys(silent: true)
            expect(subject.all_buckets).to be_empty
          end

          it 'deletes the contents of all the buckets' do
            subject.delete_all_buckets_and_keys(silent: true)
            expect(subject.buckets_content_with_values(buckets)).to be_empty
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
              expect(subject.buckets_content_with_values([bucket]))
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
              expect(subject.buckets_content_with_values([new_bucket]))
                  .to eq ({ event_key => event_value })
            end
          end
        end

        describe '#buckets_content_with_values' do
          context 'when no buckets are received' do
            let(:buckets) { [] }

            it 'returns an empty hash' do
              expect(subject.buckets_content_with_values(buckets)).to be_empty
            end
          end

          context 'when some buckets are received' do
            # I am going to use fake bucket names and invalid event keys to
            # simplify the example.
            # In each bucket, I am going to save 1 event that is only found
            # in that particular bucket, plus an event that can be found in all
            # of them. This is useful to check that union works properly and
            # does not return duplicated events.
            let(:n_buckets) { described_class.const_get(:MAX_BUCKETS_REDIS_UNION) + 1 }
            let(:unique_events) do
              (0...n_buckets).map { |event_num| { "unique_event_#{event_num}" => event_num } }
            end
            let(:repeated_event) { { 'repeated_event_0' => 0 } }
            let(:all_events) { unique_events << repeated_event }

            let(:buckets) do
              (0...n_buckets).inject({}) do |res, bucket_index|
                bucket_events = unique_events[bucket_index].merge(repeated_event)
                res.merge!(bucket_index.to_s => bucket_events)
              end
            end

            before do
              buckets.each do |bucket, events|
                events.each do |event_key, event_value|
                  subject.put_in_bucket(event_key, bucket)
                  storage.set(event_key, event_value)
                end
              end
            end

            it 'returns a hash with all the keys in the buckets and their values' do
              expect(subject.buckets_content_with_values(buckets.keys))
                  .to eq unique_events.reduce(:merge).merge(repeated_event)
            end
          end
        end
      end
    end
  end
end
