module ThreeScale
  module Backend
    module Stats
      module Aggregators
        module Base

          SERVICE_GRANULARITIES = [:eternity, :month, :week, :day, :hour].freeze
          private_constant :SERVICE_GRANULARITIES

          # For applications and users
          EXPANDED_GRANULARITIES = (SERVICE_GRANULARITIES + [:year, :minute]).freeze
          private_constant :EXPANDED_GRANULARITIES

          GRANULARITY_EXPIRATION_TIME = { minute: 180 }.freeze
          private_constant :GRANULARITY_EXPIRATION_TIME

          # Aggregates a value in a timestamp for all given keys using a specific
          # Redis command to store them. If a bucket_key is specified, each key will
          # be added to a Redis Set with that name.
          #
          # @param [Integer] value
          # @param [Time] timestamp
          # @param [Array] keys  is an array of {(service|application) => "key"}
          # @param [Symbol] cmd
          # @param [String, Nil] bucket_key
          def aggregate_values(value, timestamp, keys, cmd, bucket_key = nil)
            keys.each do |metric_type, prefix_key|
              granularities(metric_type).each do |granularity|
                key = counter_key(prefix_key, granularity, timestamp)
                expire_time = expire_time_for_granularity(granularity)

                store_key(cmd, key, value, expire_time)
                store_in_changed_keys(key, bucket_key)
              end
            end
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

          def store_in_changed_keys(key, bucket_key = nil)
            return unless bucket_key
            storage.sadd(bucket_key, key)
          end

        end
      end
    end
  end
end
