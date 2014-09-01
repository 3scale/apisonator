require_relative '../storage'
require_relative 'stats_keys'
require_relative 'stats_info'

module ThreeScale
  module Backend
    module Aggregator
      module StatsTasks

        extend StatsKeys

        module_function

        def delete_all_buckets_and_keys_only_as_rake!(options = {})
          StorageStats.disable!

          (StatsInfo.failed_buckets + StatsInfo.pending_buckets).each do |bucket|
            keys = storage.smembers(changed_keys_bucket_key(bucket))
            unless options[:silent] == true
              puts "Deleting bucket: #{bucket}, containing #{keys.size} keys"
            end
            storage.del(changed_keys_bucket_key(bucket))
          end
          storage.del(changed_keys_key);
          storage.del(failed_save_to_storage_stats_key)
          storage.del(failed_save_to_storage_stats_at_least_once_key)
        end

        private

        def self.storage
          Storage.instance
        end

      end
    end
  end
end
