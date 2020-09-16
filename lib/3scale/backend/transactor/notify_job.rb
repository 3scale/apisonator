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

              begin
                ProcessJob.perform([{
                  service_id: master_service_id,
                  application_id: application_id,
                  timestamp: timestamp,
                  usage: master_metrics.process_usage(usage)
                }])
              rescue MetricInvalid => e
                # This happens when the master account in Porta does not have
                # the notify metrics defined (by default "transactions" and
                # "transactions/authorize"). These metrics need to be created in
                # Porta, Apisonator does not have a way to guarantee that
                # they're defined.
                # Notice that this rescue prevents the job from being retried.
                # Apisonator can't know when the metrics will be created (if
                # ever) so it's better to log the error rather than retrying
                # these jobs for an undefined period of time.
                Worker.logger.notify(e)
                return [false, "#{e}"]
              rescue TransactionTimestampNotWithinRange => e
                # This is very unlikely to happen. The timestamps in a notify
                # job are not set by users, they are set by the listeners. If
                # this error happens it might mean that:
                # a) The worker started processing this job way after the
                # listener produced it. This can happen for example if we make
                # some requests to a listener with no workers. The listeners
                # will enqueue some notify jobs. If we start a worker hours
                # later, we might see this error.
                # b) There's some kind of clock skew issue.
                # c) There's a bug.
                #
                # We can't raise here, because then, the job will be retried,
                # but it's going to fail always if it has an old timestamp.
                Worker.logger.notify(e)
                return [false, "#{provider_key} #{application_id} #{e}"]
              end
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
