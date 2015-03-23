require '3scale/backend/transaction'

module ThreeScale
  module Backend
    module Transactor
      # Job for processing (aggregating and archiving) transactions.

      ## WARNING: This is not a resque job, the .perform is called by another
      ## job, either Report or NotifyJob it's meant to be like this in case we
      ## want to deatach it further
      class ProcessJob
        # @queue = :main

        def self.perform(transactions, options = {})
          transactions = preprocess(transactions)
          TransactionStorage.store_all(transactions) unless options[:master]
          Stats::Aggregator.process(transactions)
        end

        def self.preprocess(transactions)
          transactions.map do |transaction_attrs|
            transaction = Transaction.new(transaction_attrs)

            ## check if the timestamps is within accepted range
            # transaction.ensure_on_time!

            transaction
          end
        end
      end
    end
  end
end
