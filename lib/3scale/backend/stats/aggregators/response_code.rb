require '3scale/backend/stats/keys'
require '3scale/backend/transaction'
require '3scale/backend/stats/aggregators/base'

module ThreeScale
  module Backend
    module Stats
      module Aggregators
        class ResponseCode
          include Keys
          include Base

          def initialize()
            @tracked_codes = Set.new([200,404,403,500,503])
          end

          def aggregate(transaction, bucket = nil)
            response_code = extract_response_code(transaction)
            return nil unless response_code

            keys_for_multiple_codes = keys_for_response_code(transaction)
            timestamp = transaction.timestamp

            keys_for_multiple_codes.each do |keys|
              aggregate_values(1, timestamp, keys, :incrby, bucket)
            end
          end


          def keys_for_response_code(transaction)
            response_code = extract_response_code(transaction)
            return {} unless response_code
            values = values_to_inc(response_code)
            values.flat_map do |code|
              Keys.transaction_response_code_keys(transaction, code)
            end
          end

          protected
          def values_to_inc(response_code)
            keys = ["#{response_code / 100}XX"]
            keys << response_code.to_s if tracked_code?(response_code)
            keys
          end

          def tracked_code?(code)
            @tracked_codes.include?(code)
          end

          def extract_response_code(transaction)
            response_code = transaction.response_code
            if (response_code.is_a?(String) && response_code =~ /^\d{3}$/) ||
               (response_code.is_a?(Fixnum) && (100 ..999).cover?(response_code) )
              response_code.to_i
            else
              false
            end
          end
        end
      end
    end
  end
end
