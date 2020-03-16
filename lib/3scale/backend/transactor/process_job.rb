require '3scale/backend/transaction'

module ThreeScale
  module Backend
    module Transactor
      # Job for processing (aggregating and archiving) transactions.

      ## WARNING: This is not a resque job, the .perform is called by another
      ## job, either Report or NotifyJob it's meant to be like this in case we
      ## want to detach it further
      class ProcessJob

        class << self
          def perform(transactions)
            transactions = preprocess(transactions)
            Stats::Aggregator.process(transactions)
          end

          private

          def preprocess(transactions)
            transactions.map do |transaction_attrs|
              transaction = Transaction.new(transaction_attrs)
              transaction.ensure_on_time!
              transaction
            end
          end
        end

      end
    end
  end
end
