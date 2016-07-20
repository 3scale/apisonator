require '3scale/backend/stats/storage'
require '3scale/backend/stats/keys'
require '3scale/backend/application_events'
require '3scale/backend/transaction'
require '3scale/backend/stats/aggregators/response_code'
require '3scale/backend/stats/aggregators/usage'
require '3scale/backend/stats/bucket_storage'

module ThreeScale
  module Backend
    module Stats
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

          attr_accessor :prior_bucket

          # This method stores the events in buckets if that option is enabled
          # or if it was disable because of an emergency (not because a user
          # did it manually), and Kinesis has already consumed all the pending
          # buckets.
          def process(transactions)
            current_bucket = nil

            # Only disable indicating emergency if bucket storage is enabled.
            # Otherwise, we might indicate emergency when a user manually
            # disabled it previously.
            if Storage.enabled? && buckets_limit_exceeded?
              Storage.disable!(true)
              log_bucket_creation_disabled
            elsif save_in_bucket?
              Storage.enable! unless Storage.enabled?
              current_bucket = Time.now.utc.beginning_of_bucket(stats_bucket_size).to_not_compact_s
              prepare_stats_buckets(current_bucket)
            end

            touched_apps = aggregate(transactions, current_bucket)

            ApplicationEvents.generate(touched_apps.values)
            update_alerts(touched_apps)
            ApplicationEvents.ping
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
            return false unless configuration.can_create_event_buckets

            if Storage.enabled?
              true
            else
              Storage.last_disable_was_emergency? && bucket_storage.pending_buckets_size == 0
            end
          end

          def prepare_stats_buckets(current_bucket)
            store_changed_keys(current_bucket)

            if prior_bucket.nil? || current_bucket != prior_bucket
              self.prior_bucket = current_bucket
            end
          end

          def store_changed_keys(bucket = nil)
            return unless bucket
            storage.zadd(Keys.changed_keys_key, bucket.to_i, bucket)
          end

          def stats_bucket_size
            @stats_bucket_size ||= (configuration.stats.bucket_size || 5)
          end

          def storage
            Backend::Storage.instance
          end

          def bucket_storage
            @bucket_storage ||= BucketStorage.new(storage)
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
            Backend.logger.info(MAX_BUCKETS_CREATED_MSG)
          end

          def update_alerts(applications)
            current_timestamp = Time.now.getutc

            applications.each do |_appid, values|
              application = ThreeScale::Backend::Application.load(values[:service_id],
                                                                  values[:application_id])
              usage = Transactor.send(:load_application_usage, application, current_timestamp)
              status = Transactor::Status.new(application: application, values: usage)
              Validators::Limits.apply(status, {})

              max_utilization, max_record = Alerts.utilization(status)
              if max_utilization >= 0.0
                Alerts.update_utilization(status, max_utilization, max_record, current_timestamp)
              end
            end
          end
        end
      end
    end
  end
end
