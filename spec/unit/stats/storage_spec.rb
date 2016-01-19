require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/storage'

module ThreeScale
  module Backend
    module Stats
      describe Storage do
        describe ".enable!" do
          it "writes the key on redis enabling storage stats." do
            Storage.enable!
            expect(Storage.enabled?).to be_true
          end
        end

        describe ".disable!" do
          before { Storage.enable! }

          it "deletes the key on redis disabling storage stats." do
            Storage.disable!
            expect(Storage.enabled?).to be_false
          end
        end
      end
    end
  end
end
