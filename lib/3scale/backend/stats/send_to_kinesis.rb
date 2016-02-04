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
        #
        # We use Redis to ensure that using the operation set nx. The locking
        # algorithm is detailed here: http://redis.io/topics/distlock
        # Basically, every time that we want to execute a job or a flush,
        # we generate a random number and set a key (JOB_RUNNING_KEY) with that
        # random number if its current value is null. If we could set the
        # value, it means that no other job/flush is running. When the job/flush
        # finishes, it sets JOB_RUNNING_KEY to null.
        #
        # The random number that we use is the current unix epoch in ms. This
        # does not ensure 100% that two jobs will not be running at the same
        # time. In our case, this is not a problem. We assume that we can have
        # duplicated events in S3. Also, 2 jobs could be running at the same
        # time if there is a problem with the Redis master, but again, this
        # is not an issue for us.
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
