module ThreeScale
  module Backend
    class Service < ActiveRecord::Base
      after_create :create_default_metrics

      belongs_to :account
      has_many :plans, :dependent => :destroy
      has_many :metrics, :dependent => :destroy

      private 

      def create_default_metrics
        metrics.create_default!(:hits)
      end
    end
  end
end
