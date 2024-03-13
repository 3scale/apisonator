require '3scale/backend/logging'
require '3scale/backend/stats/keys'
require '3scale/backend/application_events'
require '3scale/backend/transaction'
require '3scale/backend/stats/aggregators/response_code'
require '3scale/backend/stats/aggregators/usage'

module ThreeScale
  module Backend
    module Stats

      # This class contains several methods that deal with buckets, which are
      # only used in the SaaS analytics system.
      class Aggregator
        class << self
          include Backend::StorageKeyHelpers
          include Configurable
          include Keys
          include Logging

          # This method stores the events in buckets if that option is enabled
          # or if it was disable because of an emergency (not because a user
          # did it manually), and Kinesis has already consumed all the pending
          # buckets.
          def process(transactions)
            touched_apps = aggregate(transactions)

            ApplicationEvents.generate(touched_apps.values)
            update_alerts(touched_apps)
            begin
              ApplicationEvents.ping
            rescue ApplicationEvents::PingFailed => e
              # we could not ping the frontend, log it
              logger.notify e
            end
          end

          private

          # Aggregate stats values for a collection of Transactions.
          #
          # @param [Array] transactions the collection of transactions
          # @return [Hash] A Hash where each key is an application_id and the
          #   value is another Hash with service_id and application_id.
          def aggregate(transactions)
            touched_apps = {}

            transactions.each_slice(PIPELINED_SLICE_SIZE) do |slice|
              storage.pipelined do |pipeline|
                slice.each do |transaction|
                  aggregate_all(transaction, pipeline)
                  touched_apps.merge!(touched_relation(transaction))
                end
              end
            end

            touched_apps
          end

          def aggregate_all(transaction, client)
            [Aggregators::ResponseCode, Aggregators::Usage].each do |aggregator|
              aggregator.aggregate(transaction, client)
            end
          end

          def storage
            Backend::Storage.instance
          end

          # Return a Hash with needed info to update usages and alerts.
          #
          # @param [Transaction] transaction
          # @return [Hash] the hash that contains the application_id that has
          #   been updated and the transaction's service_id. The key of the
          #   hash is the application_id.
          def touched_relation(transaction)
            relation_value = transaction.send(:application_id)
            { relation_value => { application_id: relation_value,
                                  service_id: transaction.service_id } }
          end

          def update_alerts(applications)
            current_timestamp = Time.now.getutc

            applications.each do |_appid, values|
              service_id = values[:service_id]
              application = Backend::Application.load(service_id,
                                                      values[:application_id])

              # The app could have been deleted at some point since the job was
              # enqueued. No need to update alerts in that case.
              next unless application

              # The operations below are costly. They load all the usage limits
              # and current usages to find the current utilization levels.
              # That's why before that, we check if there are any alerts that
              # can be raised.
              next unless Alerts.can_raise_more_alerts?(service_id, values[:application_id])

              application.load_metric_names
              usage = Usage.application_usage(application, current_timestamp)
              status = Transactor::Status.new(service_id: service_id,
                                              application: application,
                                              values: usage)

              max_utilization, max_record = Alerts.utilization(
                  status.application_usage_reports)

              if max_utilization >= 0.0
                Alerts.update_utilization(service_id,
                                          values[:application_id],
                                          max_utilization,
                                          max_record,
                                          current_timestamp)
              end
            end
          end
        end
      end
    end
  end
end
