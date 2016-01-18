require_relative '../storage'
require_relative 'keys'

module ThreeScale
  module Backend
    module Stats
      class Storage
        class << self
          include Memoizer::Decorator

          def enabled?
            storage.get("stats:enabled").to_i == 1
          end
          memoize :enabled?

          def active?
            storage.get("stats:active").to_i == 1
          end

          def enable!
            storage.set("stats:enabled", "1")
          end

          def activate!
            storage.set("stats:active", "1")
          end

          def disable!
            storage.del("stats:enabled")
          end

          def deactivate!
            storage.del("stats:active")
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
