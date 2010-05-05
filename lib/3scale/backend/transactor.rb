module ThreeScale
  module Backend
    # This guy is for reporting and authorizing the transactions.
    class Transactor
      def self.report(params)
        yield
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
      #   errors = {}
      #   transactions = []

      #   group_by_user_key(raw_transactions) do |user_key, raw_grouped_transactions|
      #     begin
      #       cinstance_data = CinstanceData.new(@provider_account_id, user_key)
      #       usages = cinstance_data.process_usages(raw_grouped_transactions)

      #       if cinstance_data.anonymous_clients_allowed?
      #         ensure_cinstance_exists(user_key)
      #       else
      #         cinstance_data.validate_state!           
      #         cinstance_data.usage_accumulator.pay(usages.values.sum)
      #       end

      #       raw_grouped_transactions.each do |raw_transaction|
      #         timestamp = parse_timestamp(raw_transaction[:timestamp])
      #         
      #         transactions << Transaction.new(:client_ip => raw_transaction[:client_ip],
      #                                         :created_at => timestamp,
      #                                         :provider_account_id => @provider_account_id,
      #                                         :usage => usages[raw_transaction[:index]],
      #                                         :user_key => user_key)
      #       end
      #     rescue MultipleErrors => exception
      #       errors.merge!(exception.codes)
      #     rescue Error => exception
      #       raw_grouped_transactions.each do |raw_transaction|
      #         errors[raw_transaction[:index]] = exception.code
      #       end
      #     end
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
