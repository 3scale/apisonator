require '3scale/backend/stats/redshift_job'

module ThreeScale
  module Backend
    module Stats
      class RedshiftImporter
        TTL_JOB_RUNNING_KEY_SEC = 60*60
        private_constant :TTL_JOB_RUNNING_KEY_SEC

        REDSHIFT_ENABLED_KEY = 'redshift:enabled'.freeze
        private_constant :REDSHIFT_ENABLED_KEY

        class << self
          def schedule_job
            if enabled? && Backend.production?
              lock_key = dist_lock.lock
              if lock_key
                Resque.enqueue(RedshiftJob, lock_key, Time.now.utc.to_f)
              end
            end
          end

          # Returns a UTC time that represents the hour when the newest events
          # imported in Redshift were generated or nil if nothing has been
          # imported.
          def latest_imported_events_time
            latest_timestamp = RedshiftAdapter.latest_timestamp_read
            return nil if latest_timestamp.nil?
            DateTime.parse(latest_timestamp).to_time.utc
          end

          def enable
            storage.set(REDSHIFT_ENABLED_KEY, '1')
          end

          def disable
            storage.del(REDSHIFT_ENABLED_KEY)
          end

          def enabled?
            storage.get(REDSHIFT_ENABLED_KEY).to_i == 1
          end

          # To be called by from a Redshift job once it exits so other jobs can run
          def job_finished(lock_key)
            dist_lock.unlock if lock_key == dist_lock.current_lock_key
          end

          private

          def storage
            Backend::Storage.instance
          end

          def dist_lock
            @dist_lock ||= DistributedLock.new(self.name, TTL_JOB_RUNNING_KEY_SEC, storage)
          end
        end
      end
    end
  end
end
