require 'aws-sdk'
require_relative 'send_to_kinesis_job'
require_relative 'kinesis_adapter'

module ThreeScale
  module Backend
    module Stats
      class SendToKinesis
        SEND_TO_KINESIS_ENABLED_KEY = 'send_to_kinesis:enabled'.freeze
        private_constant :SEND_TO_KINESIS_ENABLED_KEY

        JOB_RUNNING_KEY = 'send_to_kinesis:job_running'.freeze
        private_constant :JOB_RUNNING_KEY

        TTL_JOB_RUNNING_KEY_SEC = 360
        private_constant :TTL_JOB_RUNNING_KEY_SEC

        class << self
          def enable
            storage.set(SEND_TO_KINESIS_ENABLED_KEY, '1')
          end

          def disable
            storage.del(SEND_TO_KINESIS_ENABLED_KEY)
          end

          def enabled?
            storage.get(SEND_TO_KINESIS_ENABLED_KEY).to_i == 1
          end

          def schedule_job
            if enabled?
              lock_key = DateTime.now.strftime('%Q')
              unless job_running?(lock_key)
                Resque.enqueue(SendToKinesisJob, Time.now.utc, lock_key, Time.now.utc.to_f)
              end
            end
          end

          def flush_pending_events(limit = nil)
            flushed_events = 0
            if enabled?
              lock_key = DateTime.now.strftime('%Q')
              unless job_running?(lock_key)
                flushed_events = kinesis_adapter.flush(limit)
                job_finished(lock_key) # flush is not asynchronous
              end
            end
            flushed_events
          end

          def num_pending_events
            kinesis_adapter.num_pending_events
          end

          # To be called by a kinesis job once it exits so other jobs can run
          def job_finished(lock_key)
            if storage.get(JOB_RUNNING_KEY) == lock_key
              storage.del(JOB_RUNNING_KEY)
            end
          end

          private

          def storage
            Backend::Storage.instance
          end

          def config
            Backend.configuration
          end

          def kinesis_client
            Aws::Firehose::Client.new(
                region: config.kinesis_region,
                access_key_id: config.aws_access_key_id,
                secret_access_key: config.aws_secret_access_key)
          end

          def kinesis_adapter
            KinesisAdapter.new(config.kinesis_stream_name, kinesis_client, storage)
          end

          def job_running?(lock_key)
            !storage.set(JOB_RUNNING_KEY, lock_key, nx: true, ex: TTL_JOB_RUNNING_KEY_SEC)
          end
        end
      end
    end
  end
end
