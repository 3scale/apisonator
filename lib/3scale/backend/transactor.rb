require '3scale/backend/aggregation'

module ThreeScale
  module Backend
    # This guy is for reporting and authorizing the transactions.
    class Transactor
      def self.report(params)
        new.report(params)
      end

      def report(params)
        errors = {}

        provider_account_id = find_provider_account_id!(params['provider_key'])

        group_by_user_key(params['transactions']) do |user_key, grouped_transactions|
          begin
            contract_data = ContractData.new(provider_account_id, user_key)
            usages = contract_data.process_usages(grouped_transactions)

            contract_data.validate_state!           
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

      # def group_by_user_key(raw_transactions, &block)
      #   raw_transactions.map do |index, raw_transaction|
      #     raw_transaction.merge(:index => index.to_i)
      #   end.group_by do |raw_transaction|
      #     raw_transaction[:user_key] || raw_transaction[:client_ip]
      #   end.each(&block)
      # end
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
