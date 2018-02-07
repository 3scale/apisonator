require '3scale/backend/configuration'

module ThreeScale
  module Backend
    # Include this into any class to provide convenient access to the configuration.
    module Configurable
      def self.included(base)
        base.extend(self)
      end

      def configuration
        ThreeScale::Backend.configuration
      end

      def configuration=(cfg)
        ThreeScale::Backend.configuration=(cfg)
      end
    end
  end
end
