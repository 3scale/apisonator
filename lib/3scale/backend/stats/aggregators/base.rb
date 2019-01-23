module ThreeScale
  module Backend
    module Stats
      module Aggregators
        module Base
          # Aggregates a value in a timestamp for all given keys using a specific
          # Redis command to store them. If a bucket_key is specified, each key will
          # be added to a Redis Set with that name.
          #
          # @param [Integer] value
          # @param [Time] timestamp
          # @param [Array] keys array of {(service|application|user) => "key"}
          # @param [Symbol] cmd
          # @param [String, Nil] bucket
          def aggregate_values(value, timestamp, keys, cmd, bucket)
            keys_for_bucket = []

            keys.each do |metric_type, prefix_key|
              granularities(metric_type).each do |granularity|
                key = counter_key(prefix_key, granularity.new(timestamp))
                expire_time = Stats::Commons.expire_time_for_granularity(granularity)

                store_key(cmd, key, value, expire_time)

                unless Stats::Commons::EXCLUDED_FOR_BUCKETS.include?(granularity)
                  keys_for_bucket << key
                end
              end
            end

            store_in_changed_keys(keys_for_bucket, bucket) if bucket
          end

          # Return Redis command depending on raw_value.
          # If raw_value is a string with a '#' in the beginning, it returns 'set'.
          # Else, it returns 'incrby'.
          #
          # @param [String] raw_value
          # @return [Symbol] the Redis command
          def storage_cmd(raw_value)
            Backend::Usage.is_set?(raw_value) ? :set : :incrby
          end

          def storage
            Backend::Storage.instance
          end

          protected

          def granularities(metric_type)
            metric_type == :service ? Stats::Commons::SERVICE_GRANULARITIES : Stats::Commons::EXPANDED_GRANULARITIES
          end

          def store_key(cmd, key, value, expire_time = nil)
            storage.send(cmd, key, value)
            storage.expire(key, expire_time) if expire_time
          end

          def store_in_changed_keys(keys, bucket)
            bucket_storage.put_in_bucket(keys, bucket)
          end

          private

          def bucket_storage
            Stats::Storage.bucket_storage
          end
        end
      end
    end
  end
end
