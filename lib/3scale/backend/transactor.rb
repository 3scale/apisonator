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

        group_by_user_key(raw_transactions) do |user_key, grouped_transactions|
          begin
            usages = process_usages(service_id, grouped_transactions)


            # contract_data.validate_state!           
            # contract_data.usage_accumulator.pay(usages.values.sum)

            grouped_transactions.each do |transaction|
              service_id  = contract_data.service_id
              contract_id = contract_data.contract_id
              timestamp   = parse_timestamp(transaction['timestamp'])
              usage       = usages[transaction[:index]]

              Aggregation.aggregate(:service    => service_id,
                                    :cinstance  => contract_id,
                                    :created_at => timestamp,
                                    :usage      => usage)

              # TODO: archive                                    
            end
          rescue MultipleErrors => exception
            errors.merge!(exception.codes)
          rescue Error => exception
            grouped_transactions.each do |transaction|
              errors[transaction[:index]] = exception.code
            end
          end
        end
      end

      private

      def load_service_id(provider_key)
        storage.get(key_for(:service_id, :provider_key => provider_key))
      end
      
      def group_by_user_key(transactions, &block)
        transactions.map do |index, transaction|
          transaction.merge(:index => index.to_i)
        end.group_by do |transaction|
          transaction[:user_key] || transaction[:client_ip]
        end.each(&block)
      end
    
      def process_usages(service_id, transactions)
        metrics = Metrics.new(service_id)
        errors = {}

        usages = transactions.inject({}) do |usages, transaction|
          begin
            usages[transaction[:index]] = metrics.process_usage(transaction[:usage])
          rescue Error => exception
            errors[transaction[:index]] = exception.code
          end
          
          usages
        end

        raise MultipleErrors, errors unless errors.empty?
        usages
      end

      def storage
        ThreeScale::Backend.storage
      end
  
      # def self.id_from_api_key(api_key)
      #   Rails.cache.fetch("account_ids/#{api_key}") do
      #     Account.find_by_provider_key!(api_key).id
      #   end
      # end
    
      # def initialize(provider_account_id)
      #   @provider_account_id = provider_account_id
      # end

      # def report!(raw_transactions)
      #   end

      #   if errors.empty?
      #     transactions.each(&:process)
      #   else
      #     raise MultipleErrors, errors unless errors.empty?
      #   end
      # end

      # private

      # 
      # def parse_timestamp(raw_timestamp)
      #   if raw_timestamp
      #     Time.use_zone('UTC') { Time.zone.parse(raw_timestamp) }.in_time_zone(Time.zone)
      #   else
      #     Time.zone.now
      #   end
      # end

      # def ensure_cinstance_exists(user_key)
      #   Worker.asynch_ensure_cinstance_exists(:provider_account_id => @provider_account_id,
      #                                         :user_key => user_key)
      # end
    end
  end
end
