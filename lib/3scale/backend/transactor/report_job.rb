module ThreeScale
  module Backend
    module Transactor

      # Job for reporting transactions.
      class ReportJob
        @queue = :priority

        def self.perform(service_id, raw_transactions)
          transactions, logs = parse_transactions(service_id, raw_transactions)
          ProcessJob.perform(transactions)

          if !logs.nil? && logs.size > 0
            LogJob.perform(logs)                
          end

        rescue Error => error
          ErrorStorage.store(service_id, error)
        end

        def self.parse_transactions(service_id, raw_transactions)
          transactions = []
          logs = []

          group_by_application_id(service_id, raw_transactions) do |application_id, group|
            metrics  = Metric.load_all(service_id)
            group.each do |raw_transaction|
              transactions << {
                :service_id     => service_id,
                :application_id => application_id,
                :timestamp      => raw_transaction['timestamp'],
                :usage          => metrics.process_usage(raw_transaction['usage']),
                :user_id        => raw_transaction['user_id']}
      
              if (!raw_transaction['log'].nil?) 
                logs << {
                  :service_id     => service_id,
                  :application_id => application_id,
                  :timestamp      => raw_transaction['timestamp'],
                  :log            => raw_transaction['log'],
                  :user_id        => raw_transaction['user_id']
                }

              end

            end
          end

          [transactions, logs]
        end

        def self.group_by_application_id(service_id, transactions, &block)
          transactions = transactions.values if transactions.respond_to?(:values)
          transactions.group_by do |transaction|
            Application.extract_id!(service_id, transaction['app_id'], transaction['user_key'])
          end.each(&block)
        end
      end
    end
  end
end
