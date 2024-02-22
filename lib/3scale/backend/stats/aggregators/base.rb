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
          # @param [Redis] client
          def aggregate_values(value, timestamp, keys, cmd, client = storage)
            keys_for_bucket = []

            keys.each do |metric_type, prefix_key|
              granularities(metric_type).each do |granularity|
                key = counter_key(prefix_key, granularity.new(timestamp))
                expire_time = Stats::PeriodCommons.expire_time_for_granularity(granularity)

                # We don't need to store stats keys set to 0. It wastes Redis
                # memory because for rate-limiting and stats, a key of set to 0
                # is equivalent to a key that does not exist.
                if cmd == :set && value == 0
                  client.del(key)
                else
                  store_key(client, cmd, key, value, expire_time)
                end

                unless Stats::PeriodCommons::EXCLUDED_FOR_BUCKETS.include?(granularity)
                  keys_for_bucket << key
                end
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
            Backend::Usage.is_set?(raw_value) ? :set : :incrby
          end

          def storage
            Backend::Storage.instance
          end

          protected

          def granularities(metric_type)
            metric_type == :service ? Stats::PeriodCommons::SERVICE_GRANULARITIES : Stats::PeriodCommons::EXPANDED_GRANULARITIES
          end

          def store_key(client, cmd, key, value, expire_time = nil)
            client.send(cmd, key, value)
            client.expire(key, expire_time) if expire_time
          end
        end
      end
    end
  end
end
