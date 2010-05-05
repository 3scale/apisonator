module ThreeScale
  module Backend
    class Account < ActiveRecord::Base
      belongs_to :provider_account, :class_name => 'Account'
      has_many :buyer_accounts, :class_name => 'Account', :foreign_key => 'provider_account_id'
      has_one :bought_contract, :class_name => 'Contract', :foreign_key => 'user_account_id',
                                :dependent => :destroy

      def api_key
        bought_contract && bought_contract.api_key
      end
    end
  end
end
