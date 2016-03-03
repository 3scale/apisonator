require '3scale/backend/stats/redshift_job'

module ThreeScale
  module Backend
    module Stats
      class RedshiftImporter
        REDSHIFT_ENABLED_KEY = 'redshift:enabled'.freeze
        private_constant :REDSHIFT_ENABLED_KEY

        class << self
          def schedule_job
            if enabled?
              Resque.enqueue(RedshiftJob, Time.now.utc.to_f)
            end
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

          private

          def storage
            Backend::Storage.instance
          end
        end
      end
    end
  end
end
