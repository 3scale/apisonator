require '3scale/backend/stats/redshift_adapter'

module ThreeScale
  module Backend
    module Stats
      class RedshiftJob < BackgroundJob
        @queue = :stats

        class << self
          def perform_logged(_)
            begin
              latest_time_inserted = RedshiftAdapter.insert_data
              [true, job_ok_msg(latest_time_inserted)]
            rescue Exception => e
              [false, e.message]
            end
          end

          private

          def job_ok_msg(time_utc)
            "Events imported correctly. Latest ones are from: #{time_utc.to_s}"
          end
        end
      end
    end
  end
end
