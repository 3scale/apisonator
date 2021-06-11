require '3scale/backend/logging'
require '3scale/backend/stats/storage'
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
        # We need to limit the number of buckets stored in the system.
        # The reason is that our Redis can grow VERY quickly if we start
        # creating buckets and we never delete them.
        # When the max defined is reached, I simply disable the option
        # to save the stats keys in buckets. Yes, we will lose data,
        # but that is better than the alternative. We will try to find
        # a better alternative once we cannot afford to lose data.
        # Right now, we are just deleting the stats keys with
        # period = minute, so we can restore everything else.
        MAX_BUCKETS = 360
        private_constant :MAX_BUCKETS

        MAX_BUCKETS_CREATED_MSG =
            'Bucket creation has been disabled. Max number of stats buckets reached'.freeze
        private_constant :MAX_BUCKETS_CREATED_MSG

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
            current_bucket = nil

            if configuration.can_create_event_buckets
              # Only disable indicating emergency if bucket storage is enabled.
              # Otherwise, we might indicate emergency when a user manually
              # disabled it previously.
              if Storage.enabled? && buckets_limit_exceeded?
                Storage.disable!(true)
                log_bucket_creation_disabled
              elsif save_in_bucket?
                Storage.enable! unless Storage.enabled?
                current_bucket = Time.now.utc.beginning_of_bucket(stats_bucket_size)
                                             .to_not_compact_s
              end
            end

            touched_apps = aggregate(transactions, current_bucket)

            ApplicationEvents.generate(touched_apps.values)
            update_alerts(transactions)
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
          # @param [String, Nil] bucket
          # @return [Hash] A Hash where each key is an application_id and the
          #   value is another Hash with service_id and application_id.
          def aggregate(transactions, bucket = nil)
            touched_apps = {}

            transactions.each_slice(PIPELINED_SLICE_SIZE) do |slice|
              storage.pipelined do
                slice.each do |transaction|
                  aggregate_all(transaction, bucket)
                  touched_apps.merge!(touched_relation(transaction))
                end
              end
            end

            touched_apps
          end

          def aggregate_all(transaction, bucket)
            [Aggregators::ResponseCode, Aggregators::Usage].each do |aggregator|
              aggregator.aggregate(transaction, bucket)
            end
          end

          def save_in_bucket?
            if Storage.enabled?
              true
            else
              Storage.last_disable_was_emergency? && bucket_storage.pending_buckets_size == 0
            end
          end

          def stats_bucket_size
            @stats_bucket_size ||= (configuration.stats.bucket_size || 5)
          end

          def storage
            Backend::Storage.instance
          end

          def bucket_storage
            Stats::Storage.bucket_storage
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

          def buckets_limit_exceeded?
            bucket_storage.pending_buckets_size > MAX_BUCKETS
          end

          def log_bucket_creation_disabled
            logger.info(MAX_BUCKETS_CREATED_MSG)
          end

          def update_alerts(transactions)
            transactions.group_by { |tx| tx.application_id }.each do |app_id, txs|
              service_id = txs.first.service_id # All the txs of an app belong to the same service

              # The operations below are costly. They load all the usage limits
              # and current usages to find the current utilization levels.
              # That's why before that, we check if there are any alerts that
              # can be raised.
              next unless Alerts.can_raise_more_alerts?(service_id, app_id)

              begin
                max_utilization = Utilization.max_in_all_metrics(service_id, app_id)
              rescue ApplicationNotFound
                # The app could have been deleted at some point since the job
                # was enqueued. No need to update alerts in that case.
                next
              end

              if max_utilization && max_utilization.ratio > 0
                Alerts.update_utilization(service_id, app_id, max_utilization)
              end
            end
          end
        end
      end
    end
  end
end
