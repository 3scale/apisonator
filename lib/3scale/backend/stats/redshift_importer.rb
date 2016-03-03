require '3scale/backend/stats/redshift_job'

module ThreeScale
  module Backend
    module Stats
      class RedshiftImporter
        class << self
          def schedule_job
            Resque.enqueue(RedshiftJob, Time.now.utc.to_f)
          end
        end
      end
    end
  end
end
