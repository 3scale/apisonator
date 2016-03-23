require_relative '../storage'
require_relative 'keys'

module ThreeScale
  module Backend
    module Stats
      class Storage

        STATS_ENABLED_KEY = 'stats:enabled'.freeze
        private_constant :STATS_ENABLED_KEY

        DISABLED_BECAUSE_EMERGENCY_KEY = 'stats:disabled_emergency'.freeze
        private_constant :DISABLED_BECAUSE_EMERGENCY_KEY

        class << self
          include Memoizer::Decorator

          def enabled?
            storage.get(STATS_ENABLED_KEY).to_i == 1
          end
          memoize :enabled?

          def enable!
            storage.set(STATS_ENABLED_KEY, '1')
          end

          # Bucket storage can be disabled because an 'emergency' happened.
          # If too many buckets accumulate, we disable the feature because
          # the memory occupied by Redis can grow very quickly.
          # Check the code in the Aggregator class to check the conditions
          # that trigger this 'emergency'.
          def disable!(emergency = false)
            storage.del(STATS_ENABLED_KEY)

            if emergency
              storage.set(DISABLED_BECAUSE_EMERGENCY_KEY, '1')
            else
              storage.del(DISABLED_BECAUSE_EMERGENCY_KEY)
            end
          end

          # Returns whether the last time that bucket storage was disabled was
          # because of an emergency. Notice that this method can return 'true'
          # even when enabled? is true.
          def last_disable_was_emergency?
            storage.get(DISABLED_BECAUSE_EMERGENCY_KEY).to_i == 1
          end

          private

          def storage
            Backend::Storage.instance
          end
        end

      end
    end
  end
end
