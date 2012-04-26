module ThreeScale
  module Backend
    module Transactor
      # Job for processing (aggregating and archiving) transactions.
      class ProcessJob
        @queue = :main

        def self.perform(transactions, options={})
          transactions = preprocess(transactions)
          TransactionStorage.store_all(transactions) unless options[:master]
          Aggregator.aggregate_all(transactions)
          Archiver.add_all(transactions) unless options[:master]
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
