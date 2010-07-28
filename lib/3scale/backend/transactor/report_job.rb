module ThreeScale
  module Backend
    module Transactor

      # Job for reporting transactions.
      class ReportJob
        @queue = :main

        def self.perform(service_id, raw_transactions)
          transactions = parse_transactions(service_id, raw_transactions)
          ProcessJob.perform(transactions)
        rescue Error => error
          ErrorReporter.push(service_id, error)
        end

        def self.parse_transactions(service_id, raw_transactions)
          transactions = []

          group_by_user_key(raw_transactions) do |user_key, grouped_transactions|
            contract = Contract.load(service_id, user_key) || raise(UserKeyInvalid, user_key)
            metrics  = Metric.load_all(service_id)

            grouped_transactions.each do |raw_transaction|
              transactions << {
                :service_id  => service_id,
                :contract_id => contract.id,
                :timestamp   => raw_transaction['timestamp'],
                :usage       => metrics.process_usage(raw_transaction['usage'])}
            end
          end

          transactions
        end

        def self.group_by_user_key(transactions, &block)
          transactions = transactions.values if transactions.respond_to?(:values)
          transactions.group_by do |transaction|
            transaction['user_key'] || transaction['client_ip']
          end.each(&block)
        end
      end
    end
  end
end
