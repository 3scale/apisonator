require_relative '../storage'
require_relative 'keys'

module ThreeScale
  module Backend
    module Stats
      class Storage
        class << self
          include Memoizer::Decorator

          STATS_ENABLED_KEY = 'stats:enabled'.freeze
          private_constant :STATS_ENABLED_KEY

          def enabled?
            storage.get(STATS_ENABLED_KEY).to_i == 1
          end
          memoize :enabled?

          def enable!
            storage.set(STATS_ENABLED_KEY, '1')
          end

          def disable!
            storage.del(STATS_ENABLED_KEY)
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
