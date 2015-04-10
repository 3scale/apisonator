require_relative '../storage'
require_relative '../storage_influxdb'
require_relative 'keys'

module ThreeScale
  module Backend
    module Stats
      class Storage
        class << self
          include Memoizer::Decorator
          include Keys

          def instance(reset = false)
            StorageInfluxDB.instance(reset)
          end

          def enabled?
            storage.get("stats:enabled").to_i == 1
          end
          memoize :enabled?

          def active?
            storage.get("stats:active").to_i == 1
          end

          def enable!
            storage.set("stats:enabled", "1")
          end

          def activate!
            storage.set("stats:active", "1")
          end

          def disable!
            storage.del("stats:enabled")
          end

          def deactivate!
            storage.del("stats:active")
          end

          def save_changed_keys(bucket)
            keys = changed_keys_to_save(bucket)
            return if keys.empty?

            values = storage.mget(keys)
            keys.each_with_index do |key, index|
              instance.add_event(key, values[index].to_i)
            end

            instance.write_events

            clear_bucket_keys(bucket)
          rescue Exception => exception
            Airbrake.notify(exception, parameters: { bucket: bucket })
            register_failed_bucket(bucket)
          end

          private

          def register_failed_bucket(bucket)
            storage.sadd(failed_save_to_storage_stats_at_least_once_key, bucket)
            storage.sadd(failed_save_to_storage_stats_key, bucket)
          end

          def clear_bucket_keys(bucket)
            storage.pipelined do
              storage.del(changed_keys_bucket_key(bucket))
              storage.srem(failed_save_to_storage_stats_key, bucket)
            end
          end

          # @note Check if we should use sscan instead of smembers.
          #
          # @return [Array]
          def changed_keys_to_save(bucket)
            keys = storage.smembers(changed_keys_bucket_key(bucket))
            keys.reject { |key| key =~ /minute|eternity/ }
          end

          def storage
            Backend::Storage.instance
          end
        end
      end
    end
  end
end
