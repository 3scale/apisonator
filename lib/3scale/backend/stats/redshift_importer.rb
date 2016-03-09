require '3scale/backend/stats/redshift_job'

module ThreeScale
  module Backend
    module Stats
      class RedshiftImporter

        # We want to ensure that only 1 Redshift job can be running at a time.
        # In order to do that, we apply the same kind of distributed locking
        # that we are already applying in the SendToKinesis class.
        JOB_RUNNING_KEY = 'redshift:job_running'.freeze
        private_constant :JOB_RUNNING_KEY

        # If for some reason the job fails to set JOB_RUNNING_KEY to 0, other
        # jobs will not be able to execute. We solve this setting a TTL.
        # Importing events into Redshift can take a long time. I will use a
        # long TTL at least until we have a clear understanding of what the
        # process takes in production with real data.
        TTL_JOB_RUNNING_KEY_SEC = 60*60
        private_constant :TTL_JOB_RUNNING_KEY_SEC

        REDSHIFT_ENABLED_KEY = 'redshift:enabled'.freeze
        private_constant :REDSHIFT_ENABLED_KEY

        class << self
          def schedule_job
            if enabled? && Backend.production?
              lock_key = DateTime.now.strftime('%Q')
              unless job_running?(lock_key)
                Resque.enqueue(RedshiftJob, lock_key, Time.now.utc.to_f)
              end
            end
          end

          # Returns a UTC time that represents the hour when the newest events
          # imported in Redshift were generated
          def latest_imported_events_time
            latest_timestamp = RedshiftAdapter.latest_timestamp_read
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
            if storage.get(JOB_RUNNING_KEY) == lock_key
              storage.del(JOB_RUNNING_KEY)
            end
          end

          private

          def storage
            Backend::Storage.instance
          end

          def job_running?(lock_key)
            !storage.set(JOB_RUNNING_KEY, lock_key, nx: true, ex: TTL_JOB_RUNNING_KEY_SEC)
          end
        end
      end
    end
  end
end
