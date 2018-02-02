module ThreeScale
  module Backend
    # Mix this into objects that should be storable in the storage.
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
          Storage.instance
        end

        # returns array of attribute names
        def attribute_names
          raise NotImplementedError
        end
      end
    end
  end
end
