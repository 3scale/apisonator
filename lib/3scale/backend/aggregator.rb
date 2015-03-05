require '3scale/backend/cache'
require '3scale/backend/storage_stats'
require '3scale/backend/aggregator/stats_keys'
require '3scale/backend/aggregator/stats_job'
require '3scale/backend/application_events'
require '3scale/backend/transaction'

module ThreeScale
  module Backend
    module Aggregator
      include Backend::StorageKeyHelpers
      include Configurable
      include StatsKeys
      extend self

      GRANULARITY_EXPIRATION_TIME = {
        minute: 180,
      }

      attr_accessor :prior_bucket

      def process(transactions)
        current_bucket = nil

        if StorageStats.enabled?
          current_bucket = Time.now.utc.beginning_of_bucket(stats_bucket_size).to_not_compact_s
          prepare_stats_buckets(current_bucket)
        end

        touched_apps, touched_users = aggregate(transactions, current_bucket)

        ApplicationEvents.generate(touched_apps.values)
        Cache.update_status_cache(touched_apps, touched_users)
        ApplicationEvents.ping
      end

      def get_value_of_set_if_exists(value_str)
        return nil if value_str.nil? || value_str[0] != "#"
        value_str[1..value_str.size].to_i
      end

      private

      def aggregate(transactions, bucket = nil)
        touched_apps   = {}
        touched_users  = {}

        transactions.each_slice(PIPELINED_SLICE_SIZE) do |slice|
          storage.pipelined do
            slice.each do |transaction|
              aggregate_usage(transaction, bucket)

              touched_apps.merge!(touched_relation(:application, transaction))
              next unless transaction.user_id
              touched_users.merge!(touched_relation(:user, transaction))
            end
          end
        end

        [touched_apps, touched_users]
      end

      def aggregate_usage(transaction, bucket = nil)
        bucket_key = StatsKeys.changed_keys_bucket_key(bucket) if bucket

        transaction.usage.each do |metric_id, raw_value|
          cmd   = storage_cmd(raw_value)
          value = parse_usage_value(raw_value)

          aggregate_values(cmd, metric_id, value, transaction, bucket_key)
        end
      end

      def aggregate_values(cmd, metric_id, value, transaction, bucket_key)
        keys = StatsKeys.transaction_metric_keys(transaction, metric_id)

        granularities = [:eternity, :month, :week, :day, :hour]
        keys.each do |metric_type, prefix_key|
          granularities += [:year, :minute] unless metric_type == :service

          granularities.map do |granularity|
            key = counter_key(prefix_key, granularity, transaction.timestamp)
            expire_time = expire_time_for_granularity(granularity)

            store_key(cmd, key, value, expire_time)
            store_in_changed_keys(key, bucket_key)
          end
        end
      end

      def prepare_stats_buckets(current_bucket)
        store_changed_keys(current_bucket)

        if prior_bucket.nil?
          self.prior_bucket = current_bucket
        elsif current_bucket != prior_bucket
          enqueue_stats_job(prior_bucket)
          self.prior_bucket = current_bucket
        end
      end

      def store_changed_keys(bucket = nil)
        return unless bucket
        storage.zadd(StatsKeys.changed_keys_key, bucket.to_i, bucket)
      end

      def stats_bucket_size
        @stats_bucket_size ||= (configuration.stats.bucket_size || 5)
      end

      def storage
        Storage.instance
      end

      # Return Redis command depending on raw_value.
      # If raw_value is a string with a '#' in the beginning, it returns 'set'.
      # Else, it returns 'incrby'.
      #
      # @param [String] raw_value
      # @return [Symbol] the Redis command
      def storage_cmd(raw_value)
        get_value_of_set_if_exists(raw_value) ? :set : :incrby
      end

      # Parse 'raw_value' and return it as a integer.
      # It take that raw_value can start with a '#' into consideration.
      #
      # @param [String] raw_value
      # @return [Integer] the parsed value
      def parse_usage_value(raw_value)
        (get_value_of_set_if_exists(raw_value) || raw_value).to_i
      end

      def store_key(cmd, key, value, expire_time = nil)
        storage.send(cmd, key, value)
        storage.expire(key, expire_time) if expire_time
      end

      def expire_time_for_granularity(granularity)
        GRANULARITY_EXPIRATION_TIME[granularity]
      end

      def store_in_changed_keys(key, bucket_key)
        return unless bucket_key
        storage.sadd(bucket_key, key)
      end

      def enqueue_stats_job(bucket)
        return unless StorageStats.enabled?
        Resque.enqueue(StatsJob, bucket, Time.now.getutc.to_f)
      end

      # Return a Hash with needed info to update the cached XMLs
      #
      # @param [Symbol] relation
      # @param [Transaction] transaction
      # @return [Hash] the hash that contains which kind of relation has been
      #   updated (application or used) and the transaction's service_id.
      #   The key of the hash is the transaction value of that relation attr.
      def touched_relation(relation, transaction)
        relation_value = transaction.send("#{relation}_id")
        {
          relation_value => {
            :"#{relation}_id" => relation_value,
            :service_id       => transaction.service_id,
          },
        }
      end
    end
  end
end
