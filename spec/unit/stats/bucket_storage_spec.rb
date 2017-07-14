require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/bucket_storage'

module ThreeScale
  module Backend
    module Stats
      describe BucketStorage do
        let(:storage) { ThreeScale::Backend::Storage.instance }
        let(:bucket) { '20150101000000' }
        let(:event_keys) do
          ['stats/{service:11}/metric:21/day:20151207',
           'stats/{service:12}/metric:22/day:20151208']
        end

        subject { described_class.new(storage) }

        describe '#delete_bucket' do
          context 'when the bucket exists' do
            before { subject.put_in_bucket(event_keys, bucket) }

            it 'returns true' do
              expect(subject.delete_bucket(bucket)).to be true
            end

            it 'deletes the bucket from the set' do
              subject.delete_bucket(bucket)
              expect(subject.buckets).not_to include bucket
            end

            it 'deletes the contents of the bucket' do
              subject.delete_bucket(bucket)
              expect(subject.content([bucket])).to be_empty
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
              subject.put_in_bucket([event_keys[index]], bucket)
            end
          end

          context 'when the bucket exists' do
            context 'when it is the first one' do
              let(:bucket) { buckets.first }

              it 'only deletes the first one from the set of buckets' do
                subject.delete_range(bucket)
                expect(subject.buckets).to match_array buckets[1..-1]
              end

              it 'only deletes the content of the first bucket' do
                subject.delete_range(bucket)
                expect(subject.content(buckets))
                    .to match_array event_keys[1..-1]
              end
            end

            context 'when it is the last one' do
              let(:bucket) { buckets.last }

              it 'deletes all the buckets from the set of buckets' do
                subject.delete_range(bucket)
                expect(subject.buckets).to be_empty
              end

              it 'deletes the contents of all the buckets' do
                subject.delete_range(bucket)
                expect(subject.content(buckets)).to be_empty
              end
            end

            context 'when it is one in the middle' do
              let(:position) { 2 }
              let(:bucket) { buckets[position] }

              it 'deletes the bucket and the previous ones from the set of buckets' do
                subject.delete_range(bucket)
                expect(subject.buckets).to match_array buckets[(position + 1)..-1]
              end

              it 'deletes the contents of the given bucket and the previous ones' do
                subject.delete_range(bucket)
                expect(subject.content(buckets))
                    .to match_array event_keys[(position + 1)..-1]
              end
            end
          end

          context 'when the bucket does not exist' do
            context 'and it has a name that says it was created before the first one that exists' do
              let (:bucket) { '20140101000000' }

              it 'does not delete any buckets' do
                subject.delete_range(bucket)
                expect(subject.buckets).to match_array buckets
              end
            end

            context 'and it has a name that says it was created after the last one that exists' do
              let (:bucket) { (buckets.last.to_i + 10).to_s }

              it 'deletes all the buckets from the set of buckets' do
                subject.delete_range(bucket)
                expect(subject.buckets).to be_empty
              end

              it 'deletes the contents of all the buckets' do
                subject.delete_range(bucket)
                expect(subject.content(buckets)).to be_empty
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
              subject.put_in_bucket([event_keys[index]], bucket)
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
            expect(subject.buckets).to be_empty
          end

          it 'deletes the contents of all the buckets' do
            subject.delete_all_buckets_and_keys(silent: true)
            expect(subject.content(buckets)).to be_empty
          end
        end

        describe '#buckets' do
          context 'when there are not any buckets' do
            it 'returns an empty list' do
              expect(subject.buckets).to be_empty
            end
          end

          context 'when there are some buckets' do
            let(:buckets) { %w(20150101000000 20150101000010 20150101000020 20150101000030) }
            let(:event_keys) do # One event in each bucket
              ['stats/{service:11}/metric:21/day:20151207',
               'stats/{service:11}/metric:21/day:20151208',
               'stats/{service:11}/metric:21/day:20151209',
               'stats/{service:11}/metric:21/day:20151210']
            end

            before do
              buckets.each_with_index do |bucket, index|
                subject.put_in_bucket([event_keys[index]], bucket)
              end
            end

            context 'and first is not specified' do
              let(:last_index) { buckets.size - 2 }
              let(:last) { buckets[last_index] }

              it 'returns the buckets that are older or equal than last' do
                expect(subject.buckets(last: last))
                    .to match_array buckets[0..last_index]
              end
            end

            context 'and last is not specified' do
              let(:first_index) { 1 }
              let(:first) { buckets[first_index] }

              it 'returns the buckets that are newer or equal than first' do
                expect(subject.buckets(first: first))
                    .to match_array buckets[first_index..-1]
              end
            end

            context 'and neither first or last are specified' do
              it 'returns all the buckets' do
                expect(subject.buckets).to match_array buckets
              end
            end

            context 'and both first and last are specified' do
              let(:first_index) { 1 }
              let(:last_index) { buckets.size - 2 }
              let(:first) { buckets[first_index] }
              let(:last) { buckets[last_index] }

              it 'returns the buckets that are newer than first and older than last (inclusive)' do
                expect(subject.buckets(first: first, last: last))
                    .to match_array buckets[first_index..last_index]
              end
            end
          end
        end

        describe '#pending_buckets_size' do
          context 'when there are no pending buckets' do
            it 'returns 0' do
              expect(subject.pending_buckets_size).to be_zero
            end
          end

          context 'when there are pending buckets' do
            let(:buckets) { %w(20150101000000 20150101000010) }
            let(:event_keys) do
              ['stats/{service:11}/metric:21/day:20151207',
               'stats/{service:11}/metric:21/day:20151208']
            end

            before do
              buckets.each do |bucket|
                subject.put_in_bucket(event_keys, bucket)
              end
            end

            it 'returns the number of pending buckets' do
              expect(subject.pending_buckets_size).to eq buckets.size
            end
          end
        end

        describe '#put_in_bucket' do
          let(:event_keys) do
            ['stats/{service:11}/metric:21/day:20151207',
             'stats/{service:12}/metric:22/day:20151207']
          end

          context 'when the bucket exists' do
            it 'puts the events in the bucket' do
              subject.put_in_bucket(event_keys, bucket)
              expect(subject.content([bucket])).to match_array event_keys
            end
          end

          context 'when the bucket does not exist' do
            let(:new_bucket) { (bucket.to_i + 10).to_s }

            it 'creates the bucket' do
              subject.put_in_bucket(event_keys, new_bucket)
              expect(subject.buckets).to include new_bucket
            end

            it 'puts the events in the bucket' do
              subject.put_in_bucket(event_keys, new_bucket)
              expect(subject.content([new_bucket])).to match_array event_keys
            end
          end
        end

        describe '#content' do
          context 'when no buckets are received' do
            let(:buckets) { [] }

            it 'returns an empty array' do
              expect(subject.content(buckets)).to be_empty
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
              (0...n_buckets).map { |event_num| "unique_event_#{event_num}" }
            end
            let(:repeated_event) { 'repeated_event' }
            let(:all_events) { unique_events << repeated_event }

            let(:buckets) do
              (0...n_buckets).inject({}) do |res, bucket_index|
                bucket_events = [unique_events[bucket_index], repeated_event]
                res.merge!(bucket_index.to_s => bucket_events)
              end
            end

            before do
              buckets.each do |bucket, events|
                subject.put_in_bucket(events, bucket)
              end
            end

            it 'returns the content of the buckets without duplicates' do
              expect(subject.content(buckets.keys)).to match_array all_events
            end
          end
        end

        describe '#pending_keys_by_bucket' do
          context 'without pending buckets' do
            it { expect(subject.pending_keys_by_bucket).to be_empty }
            it { expect(subject.pending_keys_by_bucket).to be_kind_of Hash }
          end

          context 'with pending buckets' do
            before do
              storage.zadd(Keys.changed_keys_key, 0, 'foo')
              storage.sadd(Keys.changed_keys_bucket_key('foo'), '20100101')
              storage.sadd(Keys.changed_keys_bucket_key('foo'), '20140404')
            end

            it { expect(subject.pending_keys_by_bucket).to include('foo' => 2) }
          end
        end
      end
    end
  end
end
