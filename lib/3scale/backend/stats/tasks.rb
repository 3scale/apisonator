require_relative '../storage'
require_relative 'storage'
require_relative 'keys'
require_relative 'info'

module ThreeScale
  module Backend
    module Stats
      module Tasks
        extend Keys

        module_function

        def check_values(service_id, application_id, metric_id, timestamp)
          granularities = [:hour, :day, :week, :month, :year]
          results = { redis: {}, influxdb: {} }

          service_prefix            = service_key_prefix(service_id)
          application_prefix        = application_key_prefix(service_prefix, application_id)
          application_metric_prefix = metric_key_prefix(application_prefix, metric_id)

          granularities.each do |gra|
            redis_key               = counter_key(application_metric_prefix, gra, timestamp)
            results[:redis][gra]    = storage.get(redis_key).to_i
            results[:influxdb][gra] = storage_stats.get(service_id, metric_id, gra, timestamp, application: application_id).to_i
          end

          results
        end

        def schedule_one_stats_job(bucket = "inf")
          Resque.enqueue(Stats::ReplicateJob, bucket, Time.now.getutc.to_f)
        end

        def delete_all_buckets_and_keys_only_as_rake!(options = {})
          Stats::Storage.disable!

          (Stats::Info.failed_buckets + Stats::Info.pending_buckets).each do |bucket|
            keys = storage.smembers(changed_keys_bucket_key(bucket))
            unless options[:silent] == true
              puts "Deleting bucket: #{bucket}, containing #{keys.size} keys"
            end
            storage.del(changed_keys_bucket_key(bucket))
          end
          storage.del(changed_keys_key)
          storage.del(failed_save_to_storage_stats_key)
          storage.del(failed_save_to_storage_stats_at_least_once_key)
        end

        private

        def self.storage
          Backend::Storage.instance
        end

        def self.storage_stats
          Stats::Storage.instance
        end
      end
    end
  end
end
