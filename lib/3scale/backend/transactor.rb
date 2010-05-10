require '3scale/backend/storage_key_helpers'

module ThreeScale
  module Backend
    # This guy is for reporting and authorizing the transactions.
    class Transactor
      include StorageKeyHelpers

      def self.report(provider_key, raw_transactions)
        new.report(provider_key, raw_transactions)
      end

      def report(provider_key, raw_transactions)
        service_id = load_service_id(provider_key)
        errors = {}
        transactions = []

        group_by_user_key(raw_transactions) do |user_key, grouped_transactions|
          begin
            contract_data = load_contract_data(service_id, user_key)
            validate_contract_state(contract_data)

            usages = process_usages(service_id, grouped_transactions)

            # contract_data.usage_accumulator.pay(usages.values.sum)

            grouped_transactions.each do |transaction|
              transactions << {
                :service_id  => service_id,
                :contract_id => contract_data[:id],
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

      private

      def load_service_id(provider_key)
        result = storage.get(key_for(:service, :id, :provider_key => provider_key))
        result || raise(ProviderKeyInvalid)
      end

      def load_contract_data(service_id, user_key)
        # TODO: minimize number of redis hits here.

        id = storage.get(
          key_for(:contract, :id, {:service_id => service_id}, {:user_key => user_key}))
        id || raise(UserKeyInvalid)

        state = storage.get(key_for(:contract, :state, {:service_id => service_id}, {:id => id}))

        {:id => id, :state => state}
      end
      
      def group_by_user_key(transactions, &block)
        transactions.map do |index, transaction|
          transaction.merge('index' => index.to_i)
        end.group_by do |transaction|
          transaction['user_key'] || transaction['client_ip']
        end.each(&block)
      end

      def validate_contract_state(contract_data)
        if contract_data[:state] && contract_data[:state] != 'live'
          raise ContractNotActive
        end
      end
    
      def process_usages(service_id, transactions)
        metrics = Metrics.load(service_id)
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
        # OPTIMIZE: Maybe run this in new fiber?
        transactions.each do |transaction|
          aggregate_transaction(transaction)
          archive_transaction(transaction)
        end
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

      def storage
        ThreeScale::Backend.storage
      end
    end
  end
end
