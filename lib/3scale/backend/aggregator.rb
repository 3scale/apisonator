require '3scale/backend/cache'
require '3scale/backend/alerts'
require '3scale/backend/errors'
require '3scale/backend/storage_stats'
require '3scale/backend/aggregator/stats_keys'
require '3scale/backend/aggregator/stats_job'
require '3scale/backend/application_events'

module ThreeScale
  module Backend
    module Aggregator
      include Core::StorageKeyHelpers
      include Backend::Cache
      include Backend::Alerts
      include Configurable
      include StatsKeys
      extend self

      def aggregate_all(transactions)
        applications = Hash.new
        users        = Hash.new

        if StorageStats.enabled?
          timenow = Time.now.utc

          bucket = timenow.beginning_of_bucket(Aggregator.stats_bucket_size).to_not_compact_s
          @@current_bucket ||= bucket
          prior_bucket = (timenow - Aggregator.stats_bucket_size).beginning_of_bucket(Aggregator.stats_bucket_size).to_not_compact_s

          if current_bucket == bucket
            schedule_stats_job = false
          else
            schedule_stats_job = true
            @@current_bucket = bucket
          end
        end

        transactions.each_slice(PIPELINED_SLICE_SIZE) do |slice|
          keys_doing_set_op = []

          storage.pipelined do
            slice.each do |transaction|
              key        = transaction[:application_id]
              service_id = transaction[:service_id]
              ## the key must be application+user if users exists
              ## since this is the lowest granularity.
              ## applications contains the list of application, or
              ## application+users that need to be limit checked
              applications[key] = { application_id: key, service_id: service_id }

              if transaction[:user_id]
                key = transaction[:user_id]
                users[key] = { service_id: service_id, user_id: key }
              end

              keys_doing_set_op += aggregate(transaction)
            end
          end

          ## here the pipelined redis increments have been sent
          ## now we have to send the storage stats ones

          ## FIXME we had set operations :-/ This will only work when
          ## the key is on redis, it will not be true in the future
          ## not live keys (stats only) will only be on storage stats. Will
          ## require fix, or limit the usage of #set. In addition,
          ## set operations cannot coexist on increments on the same
          ## metric in the same pipeline. It has to be a check that
          ## set operations cannot be batched, only one transaction.

          if StorageStats.enabled? && keys_doing_set_op.size > 0
            keys_doing_set_op.each do |item|
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
        update_status_cache(applications, users)

        ## the time bucket has elapsed, trigger a stats job
        if StorageStats.enabled?
          store_changed_keys(transactions, current_bucket, prior_bucket, schedule_stats_job)
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
        return nil if value_str.nil? || value_str[0]!="#"
        return value_str[1..value_str.size].to_i
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
        ##FIXME, here we have to check that the timestamp is in the
        ##current given the time period we are in

        values = transaction[:usage].map do |metric_id, value|
          service_id = transaction[:service_id]
          val        = get_value_of_set_if_exists(value)

          if val.nil?
            cmd = :incrby
          else
            cmd   = :set
            value = val
          end

          value  = value.to_i

          if StorageStats.enabled?
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
        if user_id = transaction[:user_id]
          user_prefix = user_key_prefix(service_prefix, user_id)
          metrics.merge!(user: metric_key_prefix(user_prefix, metric_id))
        end

        granularities = [:eternity, :month, :week, :day, :hour]
        set_keys = []
        metrics.each do |metric_type, prefix|
          granularities += [:year, :minute] unless metric_type == :service

          granularities.each do |granularity|
            key  = counter_key(prefix, granularity, transaction[:timestamp])
            keys = add_to_copied_keys(cmd, bucket, key, value)
            set_keys << keys unless keys.empty?

            storage.expire(key, 180) if granularity == :minute
          end
        end

        set_keys
      end

      def add_to_copied_keys(cmd, bucket, key, value)
        set_keys = []
        if StorageStats.enabled?
          storage.sadd("keys_changed:#{bucket}", key)
          if cmd == :set
            set_keys += [key, value]
          else
            storage.send(cmd, key, value)
          end
        else
          storage.send(cmd, key, value)
        end

        set_keys
      end

      ## copied from transactor.rb
      def load_user_current_usage(user)
        pairs = Array.new
        metric_ids = Array.new
        user.usage_limits.each do |usage_limit|
          pairs << [usage_limit.metric_id, usage_limit.period]
          metric_ids << usage_limit.metric_id
        end

        return {} if pairs.nil? or pairs.size==0

        # preloading metric names
        user.metric_names = Metric.load_all_names(user.service_id, metric_ids)
        now = Time.now.getutc
        keys = pairs.map do |metric_id, period|
          user_usage_value_key(user, metric_id, period, now)
        end
        raw_values = storage.mget(*keys)
        values     = {}
        pairs.each_with_index do |(metric_id, period), index|
          values[period] ||= {}
          values[period][metric_id] = raw_values[index].to_i
        end
        values
      end

      ## copied from transactor.rb
      def load_current_usage(application)
        pairs = Array.new
        metric_ids = Array.new
        application.usage_limits.each do |usage_limit|
          pairs << [usage_limit.metric_id, usage_limit.period]
          metric_ids << usage_limit.metric_id
        end
        ## Warning this makes the test transactor_test.rb fail, weird because it didn't happen before
        return {} if pairs.nil? or pairs.size==0

        # preloading metric names
        application.metric_names = Metric.load_all_names(application.service_id, metric_ids)
        now = Time.now.getutc
        keys = pairs.map do |metric_id, period|
          usage_value_key(application, metric_id, period, now)
        end
        raw_values = storage.mget(*keys)
        values     = {}
        pairs.each_with_index do |(metric_id, period), index|
          values[period] ||= {}
          values[period][metric_id] = raw_values[index].to_i
        end
        values
      end

      def update_status_cache(applications, users = {})
        current_timestamp = Time.now.getutc

        applications.each do |appid, values|
          application = Application.load(values[:service_id],values[:application_id])
          usage = load_current_usage(application)
          status = ThreeScale::Backend::Transactor::Status.new(:application => application, :values => usage)
          ThreeScale::Backend::Validators::Limits.apply(status,{})

          max_utilization, max_record = utilization(status)
          update_utilization(status,max_utilization, max_record,current_timestamp) if max_utilization>=0.0

          set_status_in_cache_application(values[:service_id],application,status,{:exclude_user => true})
        end

        users.each do |userid, values|
          service ||= Service.load_by_id(values[:service_id])
          raise ServiceLoadInconsistency.new(values[:service_id],service.id) if service.id != values[:service_id]
          user = User.load_or_create!(service,values[:user_id])
          usage = load_user_current_usage(user)
          status = ThreeScale::Backend::Transactor::Status.new(:user => user, :user_values => usage)
          ThreeScale::Backend::Validators::Limits.apply(status,{})

          key = caching_key(service.id,:user,user.username)
          set_status_in_cache(key,status,{:exclude_application => true})
        end
      end

      def storage
        Storage.instance
      end
    end
  end
end
