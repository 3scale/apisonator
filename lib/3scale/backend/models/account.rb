module ThreeScale
  module Backend
    class Account < ActiveRecord::Base
      extend StorageKeyHelpers

      belongs_to :provider_account, :class_name => 'Account'
      has_many :buyer_accounts, :class_name => 'Account', :foreign_key => 'provider_account_id'
      has_one :bought_contract, :class_name => 'Contract', :foreign_key => 'user_account_id',
                                :dependent => :destroy

      def api_key
        bought_contract && bought_contract.api_key
      end
      
      def self.id_by_api_key(api_key)
        storage = ThreeScale::Backend.storage
        key     = key_for(:account_ids, :provider_key => api_key)

        if id = storage.get(key)
          id
        else
          id = find_id_by_api_key(api_key)
          storage.set(key, id)
          id
        end
      end

      private

      # TODO: replace this with the async version below, once i figure our the freezing
      # problem.

      def self.find_id_by_api_key(api_key)
        account = first(:conditions => {:cinstances => {:user_key => api_key}},
                        :joins => :bought_contract, :select => 'accounts.id')
        account && account.id || raise(ApiKeyInvalid)
      end


      # def self.find_id_by_api_key(api_key)
      #   fiber = Fiber.current
      #   finder = lambda do
      #     account = first(:conditions => {:cinstances => {:user_key => key}},
      #                     :join => :bought_contract, :select => :id)
      #     account.id
      #   end

      #   EM.defer(finder, fiber.method(:resume))
      #   Fiber.yield || raise ApiKeyInvalid
      # end
    end
  end
end
