require '3scale/backend/cache'
require '3scale/backend/stats/storage'
require '3scale/backend/stats/keys'
require '3scale/backend/stats/replicate_job'
require '3scale/backend/application_events'
require '3scale/backend/transaction'

module ThreeScale
  module Backend
    module Stats
      class Aggregator
        class << self
          include Backend::StorageKeyHelpers
          include Configurable
          include Keys

          GRANULARITY_EXPIRATION_TIME = {
            minute: 180,
          }

          attr_accessor :prior_bucket

          def process(transactions)
            current_bucket = nil

            if Storage.enabled?
              current_bucket = Time.now.utc.beginning_of_bucket(stats_bucket_size).to_not_compact_s
              prepare_stats_buckets(current_bucket)
            end

            touched_relations = aggregate(transactions, current_bucket)

            ApplicationEvents.generate(touched_relations[:applications].values)
            Cache.update_status_cache(touched_relations[:applications],
                                      touched_relations[:users])
            ApplicationEvents.ping
          end

          private

          # Aggregate stats values for a collection of Transactions.
          #
          # @param [Array] transactions the collection of transactions
          # @param [String, Nil] bucket
          # @return [Hash] A Hash with two keys: applications and users. Each key
          #   contains a Hash with those applications/users whose stats values have
          #   been updated.
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

            { applications: touched_apps, users: touched_users }
          end

          # Aggregates the usage of a transaction. If a bucket time is specified,
          # all new or updated stats keys will be stored in a Redis Set with a name
          # composed by 'keys_changed' + bucket.
          #
          # @param [Transaction] transaction
          # @param [String, Nil] bucket
          def aggregate_usage(transaction, bucket = nil)
            bucket_key = Keys.changed_keys_bucket_key(bucket) if bucket

            transaction.usage.each do |metric_id, raw_value|
              metric_keys = Keys.transaction_metric_keys(transaction, metric_id)
              cmd         = storage_cmd(raw_value)
              value       = parse_usage_value(raw_value)

              aggregate_values(value, transaction.timestamp, metric_keys, cmd, bucket_key)
            end
          end

          # Aggregates a value in a timestamp for all given keys using a specific
          # Redis command to store them. If a bucket_key is specified, each key will
          # be added to a Redis Set with that name.
          #
          # @param [Integer] value
          # @param [Time] timestamp
          # @param [Array] keys
          # @param [Symbol] cmd
          # @param [String, Nil] bucket_key
          def aggregate_values(value, timestamp, keys, cmd, bucket_key = nil)
            granularities = [:eternity, :month, :week, :day, :hour]
            keys.each do |metric_type, prefix_key|
              granularities += [:year, :minute] unless metric_type == :service

              granularities.each do |granularity|
                key = counter_key(prefix_key, granularity, timestamp)
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
            storage.zadd(Keys.changed_keys_key, bucket.to_i, bucket)
          end

          def stats_bucket_size
            @stats_bucket_size ||= (configuration.stats.bucket_size || 5)
          end

          def storage
            Backend::Storage.instance
          end

          # Return Redis command depending on raw_value.
          # If raw_value is a string with a '#' in the beginning, it returns 'set'.
          # Else, it returns 'incrby'.
          #
          # @param [String] raw_value
          # @return [Symbol] the Redis command
          def storage_cmd(raw_value)
            Helpers.get_value_of_set_if_exists(raw_value) ? :set : :incrby
          end

          # Parse 'raw_value' and return it as a integer.
          # It take that raw_value can start with a '#' into consideration.
          #
          # @param [String] raw_value
          # @return [Integer] the parsed value
          def parse_usage_value(raw_value)
            (Helpers.get_value_of_set_if_exists(raw_value) || raw_value).to_i
          end

          def store_key(cmd, key, value, expire_time = nil)
            storage.send(cmd, key, value)
            storage.expire(key, expire_time) if expire_time
          end

          def expire_time_for_granularity(granularity)
            GRANULARITY_EXPIRATION_TIME[granularity]
          end

          def store_in_changed_keys(key, bucket_key = nil)
            return unless bucket_key
            storage.sadd(bucket_key, key)
          end

          def enqueue_stats_job(bucket)
            return unless Storage.enabled?
            Resque.enqueue(ReplicateJob, bucket, Time.now.getutc.to_f)
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
  end
end
