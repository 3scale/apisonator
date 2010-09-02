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
          ErrorStorage.store(service_id, error)
        end

        def self.parse_transactions(service_id, raw_transactions)
          transactions = []

          group_by_application_id(raw_transactions) do |application_id, grouped_transactions|
            check_application(service_id, application_id)

            metrics  = Metric.load_all(service_id)

            grouped_transactions.each do |raw_transaction|
              transactions << {
                :service_id     => service_id,
                :application_id => application_id,
                :timestamp      => raw_transaction['timestamp'],
                :usage          => metrics.process_usage(raw_transaction['usage'])}
            end
          end

          transactions
        end

        def self.group_by_application_id(transactions, &block)
          transactions = transactions.values if transactions.respond_to?(:values)
          transactions.group_by do |transaction|
            transaction['app_id']
          end.each(&block)
        end

        def self.check_application(service_id, application_id)
          unless Application.exists?(service_id, application_id)
            raise ApplicationNotFound, application_id 
          end
        end
      end
    end
  end
end
