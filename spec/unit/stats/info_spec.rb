require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/info'

module ThreeScale
  module Backend
    module Stats
      describe Info do
        def storage
          ThreeScale::Backend::Storage.instance
        end

        describe '#pending_buckets' do
          subject { Info.pending_buckets }

          context 'without pending buckets' do
            it { expect(subject).to be_empty }
          end

          context 'with pending buckets' do
            before do
              storage.zadd(Keys.changed_keys_key, 0, "foo")
              storage.zadd(Keys.changed_keys_key, 1, "bar")
            end

            it { expect(subject).to eql(["foo", "bar"]) }
          end
        end

        describe '#pending_buckets_size' do
          subject { Info.pending_buckets_size }

          context 'without pending buckets' do
            it { expect(subject).to be(0) }
          end

          context 'with pending buckets' do
            before do
              storage.zadd(Keys.changed_keys_key, 0, "foo")
              storage.zadd(Keys.changed_keys_key, 1, "bar")
            end

            it { expect(subject).to be(2) }
          end
        end

        describe '#pending_keys_by_bucket' do
          subject { Info.pending_keys_by_bucket }

          context 'without pending buckets' do
            it { expect(subject).to be_empty }
            it { expect(subject).to be_kind_of Hash }
          end

          context 'with pending buckets' do
            before do
              storage.zadd(Keys.changed_keys_key, 0, "foo")
              storage.sadd(Keys.changed_keys_bucket_key("foo"), "20100101")
              storage.sadd(Keys.changed_keys_bucket_key("foo"), "20140404")
            end

            it { expect(subject).to include("foo" => 2) }
          end
        end

        describe '#failed_buckets' do
          subject { Info.failed_buckets }

          context 'without failed buckets' do
            it { expect(subject).to be_empty }
          end

          context 'with failed buckets' do
            before do
              storage.sadd(Keys.failed_save_to_storage_stats_key, "foo")
              storage.sadd(Keys.failed_save_to_storage_stats_key, "bar")
            end

            it { expect(subject).to include("foo", "bar") }
          end
        end

        describe '#failed_buckets_at_least_once' do
          subject { Info.failed_buckets_at_least_once }

          context 'without failed buckets' do
            it { expect(subject).to be_empty }
          end

          context 'with failed buckets' do
            before do
              storage.sadd(Keys.failed_save_to_storage_stats_at_least_once_key, "foo")
              storage.sadd(Keys.failed_save_to_storage_stats_at_least_once_key, "bar")
            end

            it { expect(subject).to include("foo", "bar") }
          end
        end
      end
    end
  end
end
