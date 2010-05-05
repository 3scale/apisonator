module ThreeScale
  module Backend
    class Contract < ActiveRecord::Base
      set_table_name 'cinstances'

      belongs_to :buyer_account, :class_name => 'Account', :foreign_key => 'user_account_id'
      belongs_to :plan

      delegate :service, :to => :plan

      def api_key
        user_key
      end
    end
  end
end
