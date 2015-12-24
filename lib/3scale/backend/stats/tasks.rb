require_relative '../storage'
require_relative 'storage'
require_relative 'keys'
require_relative 'info'
require_relative 'send_to_kinesis_job'

module ThreeScale
  module Backend
    module Stats
      module Tasks
        extend Keys

        module_function

        def delete_all_buckets_and_keys_only_as_rake!(options = {})
          Storage.disable!

          Info.pending_buckets.each do |bucket|
            keys = storage.smembers(changed_keys_bucket_key(bucket))
            unless options[:silent] == true
              puts "Deleting bucket: #{bucket}, containing #{keys.size} keys"
            end
            storage.del(changed_keys_bucket_key(bucket))
          end
          storage.del(changed_keys_key)
        end

        def schedule_send_to_kinesis_job
          if SendToKinesis.enabled?
            Resque.enqueue(SendToKinesisJob, Time.now.utc, Time.now.utc.to_f)
          end
        end

        private

        def self.storage
          Backend::Storage.instance
        end
      end
    end
  end
end
