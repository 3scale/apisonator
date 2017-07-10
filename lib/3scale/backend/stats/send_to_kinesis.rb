require_relative 'send_to_kinesis_job'

module ThreeScale
  module Backend
    module Stats

      # The main responsibility of this class is to schedule Kinesis jobs.
      # We know that the distributed locking algorithm that we are using
      # guarantees that two jobs will not be running at the same time except
      # in some corner cases, like in the case of a failure of one of the Redis
      # masters. However, this is not a problem in our case. If two Kinesis
      # jobs run at the same time, they will probably export the same events to
      # Kinesis. However, they will not be imported twice into Redshift because
      # the import method that we use detects that two events are the same and
      # only imports one. This detection is done using the 'time_gen' field
      # that we attach to each event before they are send to Kinesis.
      class SendToKinesis
        SEND_TO_KINESIS_ENABLED_KEY = 'send_to_kinesis:enabled'.freeze
        private_constant :SEND_TO_KINESIS_ENABLED_KEY

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
              lock_key = dist_lock.lock
              if lock_key
                Resque.enqueue(SendToKinesisJob, Time.now.utc, lock_key, Time.now.utc.to_f)
              end
            end
          end

          def flush_pending_events(limit = nil)
            flushed_events = 0
            if enabled?
              lock_key = dist_lock.lock
              if lock_key
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
            dist_lock.unlock if lock_key == dist_lock.current_lock_key
          end

          private

          def storage
            Backend::Storage.instance
          end

          def kinesis_adapter
            Stats::Storage.kinesis_adapter
          end

          def dist_lock
            @dist_lock ||= DistributedLock.new(self.name, TTL_JOB_RUNNING_KEY_SEC, storage)
          end
        end
      end
    end
  end
end
