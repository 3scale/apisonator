require_relative '../spec_helper'
require_relative '../../lib/3scale/backend/storage_stats'

module ThreeScale
  module Backend
    describe StorageStats do
      describe ".enable!" do
        it "writes the key on redis enabling storage stats." do
          StorageStats.enable!
          expect(StorageStats.enabled?).to be_true
        end
      end

      describe ".activate!" do
        it "writes the key on redis activating storage stats." do
          StorageStats.activate!
          expect(StorageStats.active?).to be_true
        end
      end

      describe ".disable!" do
        before { StorageStats.enable! }

        it "deletes the key on redis disabling storage stats." do
          StorageStats.disable!
          expect(StorageStats.enabled?).to be_false
        end
      end

      describe ".deactivate!" do
        before { StorageStats.activate! }

        it "deletes the key on redis deactivating storage stats." do
          StorageStats.deactivate!
          expect(StorageStats.active?).to be_false
        end
      end

    end
  end
end
