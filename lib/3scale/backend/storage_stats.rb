require_relative 'storage'
require_relative 'storage_influxdb'
require_relative 'aggregator/stats_keys'

module ThreeScale
  module Backend
    module StorageStats

      extend Aggregator::StatsKeys

      def self.instance(reset = false)
        StorageInfluxDB.instance(reset)
      end

      def self.enabled?
        storage.get("stats:enabled").to_i == 1
      end

      def self.active?
        storage.get("stats:active").to_i == 1
      end

      def self.enable!
        storage.set("stats:enabled", "1")
      end

      def self.activate!
        storage.set("stats:active", "1")
      end

      def self.disable!
        storage.del("stats:enabled")
      end

      def self.deactivate!
        storage.del("stats:active")
      end

      def self.save_changed_keys(bucket)
        keys = changed_keys_to_save(bucket)
        return if keys.empty?

        values = storage.mget(*keys)
        keys.each_with_index do |key, index|
          instance.add_event(key, values[index].to_i)
        end

        instance.write_events

        clear_bucket_keys(bucket)
      rescue Exception => exception
        begin
          Airbrake.notify(exception, parameters: { bucket: bucket })
        rescue Exception => no_airbrake
          ## this is a bit hackish... this will only happens when
          ## save_changed_keys blows when called from a rake task
          ## (rake stats:process_failed)
          puts "Error: #{exception.inspect}. #{no_airbrake}"
        end
        register_failed_bucket(bucket)
      end

      private

      def self.register_failed_bucket(bucket)
        storage.sadd(failed_save_to_storage_stats_at_least_once_key, bucket)
        storage.sadd(failed_save_to_storage_stats_key, bucket)
      end

      def self.clear_bucket_keys(bucket)
        storage.pipelined do
          storage.del(changed_keys_bucket_key(bucket))
          storage.srem(failed_save_to_storage_stats_key, bucket)
        end
      end

      # @note Check if we should use sscan instead of smembers.
      #
      # @return [Array]
      def self.changed_keys_to_save(bucket)
        keys = storage.smembers(changed_keys_bucket_key(bucket))
        keys.reject { |key| key =~ /minute|eternity/ }
      end

      def self.storage
        Storage.instance
      end

    end
  end
end
