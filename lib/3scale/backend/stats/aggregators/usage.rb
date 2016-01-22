require '3scale/backend/stats/keys'
require '3scale/backend/transaction'
require '3scale/backend/stats/aggregators/base'

module ThreeScale
  module Backend
    module Stats
      module Aggregators
        class Usage
          class << self
            include Keys
            include Base

            # Aggregates the usage of a transaction. If a bucket time is specified,
            # all new or updated stats keys will be stored in a Redis Set.
            #
            # @param [Transaction] transaction
            # @param [String, Nil] bucket
            def aggregate(transaction, bucket = nil)
              bucket_key = Keys.changed_keys_bucket_key(bucket) if bucket

              transaction.usage.each do |metric_id, raw_value|
                metric_keys = Keys.transaction_keys(transaction, :metric, metric_id)
                cmd         = storage_cmd(raw_value)
                value       = parse_usage_value(raw_value)

                aggregate_values(value, transaction.timestamp, metric_keys, cmd, bucket_key)
              end
            end

          end
        end
      end
    end
  end
end
