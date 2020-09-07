module ThreeScale
  module Backend
    module Transactor
      #
      # Job for notifying about backend calls.
      class NotifyJob < BackgroundJob
        extend Configurable
        @queue = :main

        class << self
          def perform_logged(provider_key, usage, timestamp, _enqueue_time)
            application_id = Application.load_id_by_key(master_service_id, provider_key)

            if application_id && Application.exists?(master_service_id, application_id)
              master_metrics = Metric.load_all(master_service_id)

              ProcessJob.perform([{
                service_id: master_service_id,
                application_id: application_id,
                timestamp: timestamp,
                usage: master_metrics.process_usage(usage)
              }])
            end
            [true, "#{provider_key} #{application_id || '--'}"]
          end

          private

          def master_service_id
            configuration.master_service_id.to_s
          end
        end
      end

    end
  end
end
