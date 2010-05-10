require '3scale/backend/storage_key_helpers'

module ThreeScale
  module Backend
    module Storable
      include StorageKeyHelpers

      def self.included(base)
        base.extend(ClassMethods)
      end

      def initialize(attributes = {})
        attributes.each do |key, value|
          send("#{key}=", value)
        end
      end

      def storage
        self.class.storage
      end

      module ClassMethods
        include StorageKeyHelpers
      
        def storage
          ThreeScale::Backend.storage
        end
      end
    end
  end
end
