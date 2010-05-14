require '3scale/backend/storage_key_helpers'

module ThreeScale
  module Backend
    # Methods for reporting and authorizing transactions.
    module Transactor
      extend self

      include StorageKeyHelpers
      include Configurable

      def report(provider_key, raw_transactions)
        report_backend_hit(provider_key, 'transactions/create_multiple' => 1,
                                         'transactions' => raw_transactions.size)

        service_id = Service.load_id(provider_key) || raise(ProviderKeyInvalid)
        errors = {}
        transactions = []

        group_by_user_key(raw_transactions) do |user_key, grouped_transactions|
          begin
            contract = Contract.load(service_id, user_key) || raise(UserKeyInvalid)
            validate_contract_state(contract)

            usages = process_usages(service_id, grouped_transactions)

            # contract_data.usage_accumulator.pay(usages.values.sum)

            grouped_transactions.each do |transaction|
              transactions << {
                :service_id  => service_id,
                :contract_id => contract.id,
                :timestamp   => parse_timestamp(transaction['timestamp']),
                :usage       => usages[transaction['index']]}
            end
          rescue MultipleErrors => exception
            errors.merge!(exception.codes)
          rescue Error => exception
            grouped_transactions.each do |transaction|
              errors[transaction['index']] = exception.code
            end
          end
        end

        if errors.empty?
          process_transactions(transactions)
        else
          raise MultipleErrors.new(errors) unless errors.empty?
        end
      end

      def authorize(provider_key, user_key)
        report_backend_hit(provider_key, 'transactions/authorize' => 1)

        service_id = Service.load_id(provider_key) || raise(ProviderKeyInvalid)
        contract   = Contract.load(service_id, user_key) || raise(UserKeyInvalid)
        
        validate_contract_state(contract)

        Status.new(contract)
      end

      private
      
      def group_by_user_key(transactions, &block)
        transactions.map do |index, transaction|
          transaction.merge('index' => index.to_i)
        end.group_by do |transaction|
          transaction['user_key'] || transaction['client_ip']
        end.each(&block)
      end

      def validate_contract_state(contract)
        if contract.state && contract.state != :live
          raise ContractNotActive
        end
      end
    
      def process_usages(service_id, transactions)
        metrics = Metric.load_all(service_id)
        errors = {}

        usages = transactions.inject({}) do |usages, transaction|
          begin
            usages[transaction['index']] = metrics.process_usage(transaction['usage'])
          rescue Error => exception
            errors[transaction['index']] = exception.code
          end
          
          usages
        end

        raise MultipleErrors, errors unless errors.empty?
        usages
      end
      
      def parse_timestamp(raw_timestamp)
        if raw_timestamp
          Time.parse_to_utc(raw_timestamp)
        else
          Time.now.getutc
        end
      end

      def process_transactions(transactions)
        transactions.each do |transaction|
          process_transaction(transaction)
        end
      end

      def process_transaction(transaction)
        aggregate_transaction(transaction)
        archive_transaction(transaction)
      end

      def aggregate_transaction(transaction)
        # Rename some fields, for backward compatibility.
        Aggregation.aggregate(:service   => transaction[:service_id],
                              :cinstance => transaction[:contract_id],
                              :timestamp => transaction[:timestamp],
                              :usage     => transaction[:usage])
      end

      def archive_transaction(transaction)
        Archiver.add(transaction)
      end

      def report_backend_hit(provider_key, usage)
        contract = Contract.load(master_service_id, provider_key) || raise(ProviderKeyInvalid)
        master_metrics = Metric.load_all(master_service_id)

        process_transaction(:service_id  => master_service_id,
                            :contract_id => contract.id,
                            :timestamp   => Time.now.getutc,
                            :usage       => master_metrics.process_usage(usage))
      end

      def master_service_id
        Service.load_id(configuration.master_provider_key) || raise("Can't load master service id. Make sure the \"main.master_provider_key\" configuration value is set correctly")
      end

      def storage
        ThreeScale::Backend.storage
      end
    end
  end
end
