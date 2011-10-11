module ThreeScale
  module Backend
    module Transactor
      # Job to process the api calls between buyer and provider
      class LogJob
        @queue = :main

        def self.perform(transactions)
          transactions = preprocess(transactions)
          LogStorage.store_all(transactions)          
        end

        def self.preprocess(transactions)
          transactions.map do |transaction|
            transaction = transaction.symbolize_keys
            transaction[:timestamp] = parse_timestamp(transaction[:timestamp])
            transaction
          end
        end

        def self.parse_timestamp(timestamp)
          return timestamp if timestamp.is_a?(Time)
          ts = Time.parse_to_utc(timestamp)
          if ts.nil?
            return Time.now.getutc 
          else
            return ts
          end          
        end
      end
    end
  end
end
