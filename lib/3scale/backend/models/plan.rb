module ThreeScale
  module Backend
    class Plan < ActiveRecord::Base
      belongs_to :service

      def provider_account
        service && service.account
      end
    end
  end
end
