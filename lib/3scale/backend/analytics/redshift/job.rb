module ThreeScale
  module Backend
    module Analytics
      module Redshift
        class Job < BackgroundJob
          @queue = :stats

          class << self
            def perform_logged(lock_key, _enqueue_time)
              begin
                latest_time_inserted = Adapter.insert_pending_events
                ok = true
                msg = job_ok_msg(latest_time_inserted)
              rescue Exception => e
                ok = false
                msg = e.message
              end

              Importer.job_finished(lock_key)
              [ok, msg]
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
end
