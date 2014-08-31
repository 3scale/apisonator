require_relative 'storage'

module ThreeScale
  module Backend
    module StorageStats

      def self.enabled?
        storage.get("stats:enabled").to_i == 1
      end

      def self.active?
        storage.get("stats:active").to_i == 1
      end

      def self.enable!
        storage.set("stats:enabled", "1")
      end

      def self.activate!
        storage.set("stats:active", "1")
      end

      def self.disable!
        storage.del("stats:enabled")
      end

      def self.deactivate!
        storage.del("stats:active")
      end

      private

      def self.storage
        Storage.instance
      end

    end
  end
end
