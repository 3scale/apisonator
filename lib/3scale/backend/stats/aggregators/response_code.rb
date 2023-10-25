require '3scale/backend/stats/keys'
require '3scale/backend/transaction'
require '3scale/backend/stats/aggregators/base'

module ThreeScale
  module Backend
    module Stats
      module Aggregators
        class ResponseCode
          class << self
            include Keys
            include Base

            def aggregate(transaction, client = storage)
              keys_for_multiple_codes = keys_for_response_code(transaction)
              timestamp = transaction.timestamp

              keys_for_multiple_codes.each do |keys|
                aggregate_values(1, timestamp, keys, :incrby, client)
              end
            end


            protected
            def keys_for_response_code(transaction)
              response_code = transaction.extract_response_code
              return {} unless response_code
              values = values_to_inc(response_code)
              values.flat_map do |code|
                Keys.transaction_keys(transaction, :response_code, code)
              end
            end

            def values_to_inc(response_code)
              group_code = Stats::CodesCommons.get_http_code_group(response_code)
              [].tap do |keys|
                keys << group_code if tracked_group_code?(group_code)
                keys << response_code.to_s if tracked_code?(response_code)
              end
            end

            def tracked_code?(code)
              Stats::CodesCommons::TRACKED_CODES.include?(code)
            end

            def tracked_group_code?(group_code)
              Stats::CodesCommons::TRACKED_CODE_GROUPS.include?(group_code)
            end
          end
        end
      end
    end
  end
end
