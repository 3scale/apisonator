require '3scale/backend/cache'
require '3scale/backend/alerts'
require '3scale/backend/errors'
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
        applications   = Hash.new
        users          = Hash.new

        if StorageStats.enabled?
          current_bucket = Time.now.utc.beginning_of_bucket(stats_bucket_size).to_not_compact_s
          prepare_stats_buckets(current_bucket)
        end

        transactions.each_slice(PIPELINED_SLICE_SIZE) do |slice|
          storage.pipelined do
            slice.each do |transaction|
              key        = transaction.application_id
              service_id = transaction.service_id
              ## the key must be application+user if users exists
              ## since this is the lowest granularity.
              ## applications contains the list of application, or
              ## application+users that need to be limit checked
              applications[key] = { application_id: key, service_id: service_id }

              if transaction.user_id
                key = transaction.user_id
                users[key] = { service_id: service_id, user_id: key }
              end

              aggregate(transaction, current_bucket)
            end
          end
        end

        ApplicationEvents.generate(applications.values)

        ## now we have done all incrementes for all the transactions, we
        ## need to update the cached_status for for the transactor
        ThreeScale::Backend::Cache.update_status_cache(applications, users)

        ApplicationEvents.ping
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

      def get_value_of_set_if_exists(value_str)
        return nil if value_str.nil? || value_str[0] != "#"
        value_str[1..value_str.size].to_i
      end

      def reset_current_bucket!
        self.prior_bucket = nil
      end

      def stats_bucket_size
        @stats_bucket_size ||= (configuration.stats.bucket_size || 5)
      end

      private

      def aggregate(transaction, bucket = nil)
        bucket_key = "keys_changed:#{bucket}" if bucket
        ##FIXME, here we have to check that the timestamp is in the
        ##current given the time period we are in
        transaction.usage.each do |metric_id, raw_value|
          cmd   = storage_cmd(raw_value)
          value = parse_usage_value(raw_value)

          aggregate_values(cmd, metric_id, value, transaction, bucket_key)
        end
      end

      def aggregate_values(cmd, metric_id, value, transaction, bucket_key)
        service_prefix = service_key_prefix(transaction.service_id)
        application_prefix = application_key_prefix(service_prefix, transaction.application_id)

        metrics = {
          service: metric_key_prefix(service_prefix, metric_id),
          application: metric_key_prefix(application_prefix, metric_id),
        }

        # this one is for the limits of the users
        user_id = transaction.user_id
        if user_id
          user_prefix = user_key_prefix(service_prefix, user_id)
          metrics.merge!(user: metric_key_prefix(user_prefix, metric_id))
        end

        granularities = [:eternity, :month, :week, :day, :hour]
        metrics.each do |metric_type, prefix|
          granularities += [:year, :minute] unless metric_type == :service

          granularities.map do |granularity|
            key = counter_key(prefix, granularity, transaction.timestamp)
            expire_time = expire_time_for_granularity(granularity)

            store_key(cmd, key, value, expire_time)
            store_in_changed_keys(key, bucket_key)
          end
        end
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
    end
  end
end
