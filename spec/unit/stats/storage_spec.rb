require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/storage'

module ThreeScale
  module Backend
    module Stats
      describe Storage do
        describe '.enable!' do
          it 'writes the key on redis enabling storage stats.' do
            Storage.enable!
            expect(Storage.enabled?).to be true
          end
        end

        describe '.disable!' do
          before { Storage.enable! }

          context 'when called because of an emergency' do
            it 'deletes the key on redis disabling storage stats.' do
              Storage.disable!
              expect(Storage.enabled?).to be false
            end

            it 'marks in Redis that disable was because of an emergency' do
              # Memoizer needs to be reset because .last_disable_was_emergency?
              # is memoized.
              expect { Storage.disable!(true); Memoizer.reset! }
                  .to change(Storage, :last_disable_was_emergency?)
                  .from(false).to(true)
            end
          end

          context 'when not called because of an emergency' do
            # Force that latest was an emergency, so we can check it changes
            before do
              Storage.send(:storage).set(Storage.const_get(:DISABLED_BECAUSE_EMERGENCY_KEY), '1')
            end

            it 'deletes the key on redis disabling storage stats.' do
              Storage.disable!
              expect(Storage.enabled?).to be false
            end

            it 'marks in Redis that disable was not because of an emergency' do
              # Memoizer needs to be reset because .last_disable_was_emergency?
              # is memoized.
              expect { Storage.disable!(false); Memoizer.reset! }
                  .to change(Storage, :last_disable_was_emergency?)
                  .from(true).to(false)
            end
          end
        end
      end
    end
  end
end
