module ThreeScale
  module Backend
    module Stats
      module Aggregators
        module Base

          SERVICE_GRANULARITIES =
            [:eternity, :month, :week, :day, :hour].map do |g|
              Period[g]
            end.freeze
          private_constant :SERVICE_GRANULARITIES

          # For applications and users
          EXPANDED_GRANULARITIES = (SERVICE_GRANULARITIES +
                                    [Period[:year], Period[:minute]]).freeze
          private_constant :EXPANDED_GRANULARITIES

          GRANULARITY_EXPIRATION_TIME = { Period[:minute] => 180 }.freeze
          private_constant :GRANULARITY_EXPIRATION_TIME

          # We are not going to send metrics with granularity 'eternity' or
          # 'week' to Kinesis, so there is no point in storing them in Redis
          # buckets.
          EXCLUDED_FOR_BUCKETS = [Period[:eternity], Period[:week]].freeze
          private_constant :EXCLUDED_FOR_BUCKETS

          # Aggregates a value in a timestamp for all given keys using a specific
          # Redis command to store them. If a bucket_key is specified, each key will
          # be added to a Redis Set with that name.
          #
          # @param [Integer] value
          # @param [Time] timestamp
          # @param [Array] keys array of {(service|application|user) => "key"}
          # @param [Symbol] cmd
          # @param [String, Nil] bucket_key
          def aggregate_values(value, timestamp, keys, cmd, bucket_key = nil)
            keys_for_bucket = []

            keys.each do |metric_type, prefix_key|
              granularities(metric_type).each do |granularity|
                key = counter_key(prefix_key, granularity.new(timestamp))
                expire_time = expire_time_for_granularity(granularity)

                store_key(cmd, key, value, expire_time)

                unless EXCLUDED_FOR_BUCKETS.include?(granularity)
                  keys_for_bucket << key
                end
              end
            end

            store_in_changed_keys(keys_for_bucket, bucket_key)
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
            metric_type == :service ? SERVICE_GRANULARITIES : EXPANDED_GRANULARITIES
          end

          def store_key(cmd, key, value, expire_time = nil)
            storage.send(cmd, key, value)
            storage.expire(key, expire_time) if expire_time
          end

          def expire_time_for_granularity(granularity)
            GRANULARITY_EXPIRATION_TIME[granularity]
          end

          def store_in_changed_keys(keys, bucket_key = nil)
            return unless bucket_key
            storage.sadd(bucket_key, keys)
          end

        end
      end
    end
  end
end
