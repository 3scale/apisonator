module ThreeScale
  module Backend
    module Transactor
      # Job for processing (aggregating and archiving) transactions.
      class ProcessJob
        @queue = :main

        def self.perform(transactions)
          transactions = preprocess(transactions)

          Aggregator.aggregate(transactions)
          Archiver.add(transactions)
        end

        def self.preprocess(transactions)
          transactions.map do |transaction|
            transaction = transaction.symbolize_keys
            transaction[:timestamp] = parse_timestamp(transaction[:timestamp])
            transaction
          end
        end

        def self.parse_timestamp(timestamp)
          return Time.now.getutc              if timestamp.nil?
          return timestamp                    if timestamp.is_a?(Time)
          return Time.parse_to_utc(timestamp)
        end
      end
    end
  end
end
