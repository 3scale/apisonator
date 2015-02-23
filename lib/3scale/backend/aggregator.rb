require 'json'
require '3scale/backend'
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

      def process(transactions)
        applications = Hash.new
        users        = Hash.new

        Memoizer.memoize_block("stats-enabled") do
          @stats_enabled = StorageStats.enabled?
        end

        if @stats_enabled
          timenow = Time.now.utc

          bucket = timenow.beginning_of_bucket(Aggregator.stats_bucket_size).to_not_compact_s
          @@current_bucket ||= bucket
          @@prior_bucket = (timenow - Aggregator.stats_bucket_size).beginning_of_bucket(Aggregator.stats_bucket_size).to_not_compact_s

          if @@current_bucket == bucket
            schedule_stats_job = false
          else
            schedule_stats_job = true
            @@current_bucket = bucket
          end
        end

        transactions.each_slice(PIPELINED_SLICE_SIZE) do |slice|
          @keys_doing_set_op = []

          storage.pipelined do
            @keys_doing_set_op = slice.map do |transaction|
              key        = transaction[:application_id]
              service_id = transaction[:service_id]
              ## the key must be application+user if users exists
              ## since this is the lowest granularity.
              ## applications contains the list of application, or
              ## application+users that need to be limit checked
              applications[key] = { application_id: key, service_id: service_id }
              ## who puts service_id here? it turns out is
              ## the transactor.report_enqueue
              if transaction[:service_id].nil?
              end

              if transaction[:user_id]
                key = transaction[:user_id]
                users[key] = { service_id: service_id, user_id: key }
              end

              aggregate(transaction)
            end
          end

          @keys_doing_set_op.flatten!(1)

          ## here the pipelined redis increments have been sent
          ## now we have to send the storage stats ones

          ## FIXME we had set operations :-/ This will only work when
          ## the key is on redis, it will not be true in the future
          ## not live keys (stats only) will only be on storage stats. Will
          ## require fix, or limit the usage of #set. In addition,
          ## set operations cannot coexist on increments on the same
          ## metric in the same pipeline. It has to be a check that
          ## set operations cannot be batched, only one transaction.

          if @stats_enabled && @keys_doing_set_op.size > 0
            @keys_doing_set_op.each do |item|
              key, value = item

              storage.pipelined do
                storage.get(key)
                storage.set(key, value)
              end
            end
          end
        end

        ApplicationEvents.generate(applications.values)

        ## now we have done all incrementes for all the transactions, we
        ## need to update the cached_status for for the transactor
        ThreeScale::Backend::Cache.update_status_cache(applications, users)

        ## the time bucket has elapsed, trigger a stats job
        if @stats_enabled
          store_changed_keys(transactions, @@current_bucket, @@prior_bucket, schedule_stats_job)
        end

        ApplicationEvents.ping
      end

      def store_changed_keys(transactions, bucket, prior_bucket, schedule_stats_job)
        transactions.each do |transaction|
          service_id = transaction[:service_id]
          bucket_key = bucket_with_service_key(bucket, service_id)
          storage.zadd(changed_keys_key, bucket.to_i, bucket_key)

          if schedule_stats_job
            ## this will happend every X seconds, N times. Where N is the number of workers
            ## and X is a configuration parameter
            prior_bucket_key = bucket_with_service_key(prior_bucket, service_id)
            Resque.enqueue(StatsJob, prior_bucket_key, Time.now.getutc.to_f)
          end
        end
      end

      def get_value_of_set_if_exists(value_str)
        return nil if value_str.nil? || value_str[0] != "#"
        value_str[1..value_str.size].to_i
      end

      def reset_current_bucket!
        @@current_bucket = nil
      end

      def current_bucket
        @@current_bucket
      end

      def stats_bucket_size
        @@stats_bucket_size ||= (configuration.stats.bucket_size || 5)
      end

      private

      def aggregate(transaction)
        service_id = transaction[:service_id]

        ##FIXME, here we have to check that the timestamp is in the
        ##current given the time period we are in
        values = transaction[:usage].map do |metric_id, raw_value|
          cmd   = storage_cmd(raw_value)
          value = parse_usage_value(raw_value)

          if @stats_enabled
            bucket_key = bucket_with_service_key(current_bucket, service_id)
          else
            bucket_key = ""
          end

          aggregate_values(cmd, metric_id, value, transaction, bucket_key)
        end

        values.flatten(1)
      end

      def aggregate_values(cmd, metric_id, value, transaction, bucket)
        service_prefix = service_key_prefix(transaction[:service_id])
        application_prefix = application_key_prefix(service_prefix, transaction[:application_id])

        metrics = {
          service: metric_key_prefix(service_prefix, metric_id),
          application: metric_key_prefix(application_prefix, metric_id),
        }

        # this one is for the limits of the users
        user_id = transaction[:user_id]
        if user_id
          user_prefix = user_key_prefix(service_prefix, user_id)
          metrics.merge!(user: metric_key_prefix(user_prefix, metric_id))
        end

        granularities = [:eternity, :month, :week, :day, :hour]
        values = metrics.map do |metric_type, prefix|
          granularities += [:year, :minute] unless metric_type == :service

          granularities.map do |granularity|
            key = counter_key(prefix, granularity, transaction[:timestamp])
            keys = add_to_copied_keys(cmd, bucket, key, value)
            storage.expire(key, 180) if granularity == :minute

            keys
          end
        end

        values.flatten(1).reject(&:empty?)
      end

      def add_to_copied_keys(cmd, bucket, key, value)
        set_keys = []
        if @stats_enabled
          storage.sadd("keys_changed:#{bucket}", key)
          if cmd == :set
            @keys_doing_set_op << [key, value]
            set_keys += [key, value]
          else
            storage.send(cmd, key, value)
          end
        else
          storage.send(cmd, key, value)
        end

        set_keys
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
    end
  end
end
