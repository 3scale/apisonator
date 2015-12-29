require 'aws-sdk'
require_relative 'send_to_kinesis_job'
require_relative 'kinesis_adapter'

module ThreeScale
  module Backend
    module Stats
      class SendToKinesis
        SEND_TO_KINESIS_ENABLED_KEY = 'send_to_kinesis:enabled'.freeze
        private_constant :SEND_TO_KINESIS_ENABLED_KEY

        # We want to avoid having two jobs running at the same time. That could
        # lead to sending repeated events to Kinesis.
        # Similarly, we do not want to execute 2 flushes concurrently, or
        # execute one when a kinesis job is running.
        # We use Redis to ensure that, using the atomic operation incr.
        JOB_RUNNING_KEY = 'send_to_kinesis:job_running'.freeze
        private_constant :JOB_RUNNING_KEY

        # If for some reason the job fails to set JOB_RUNNING_KEY to 0, other
        # jobs will not be able to execute. We solve this setting a TTL.
        TTL_JOB_RUNNING_KEY_SEC = 120
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
            if enabled? && !job_running?
              Resque.enqueue(SendToKinesisJob, Time.now.utc, Time.now.utc.to_f)
            end
          end

          def flush_pending_events
            if enabled? && !job_running?
              kinesis_adapter.flush
              job_finished # flush is not asynchronous
            end
          end

          # To be called by a kinesis job once it exits so other jobs can run
          def job_finished
            storage.del(JOB_RUNNING_KEY)
          end

          private

          def storage
            Backend::Storage.instance
          end

          def kinesis_adapter
            kinesis_client = Aws::Firehose::Client.new(
                region: config.kinesis_region,
                access_key_id: config.aws_access_key_id,
                secret_access_key: config.aws_secret_access_key)
            KinesisAdapter.new(config.kinesis_stream_name, kinesis_client, storage)
          end

          def job_running?
            job_running = (storage.incr(JOB_RUNNING_KEY).to_i != 1)

            unless job_running
              storage.expire(JOB_RUNNING_KEY, TTL_JOB_RUNNING_KEY_SEC)
            end

            job_running
          end
        end
      end
    end
  end
end
