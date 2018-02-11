require '3scale/backend/configuration'
require '3scale/backend/logging/external/impl'

module ThreeScale
  module Backend
    module Logging
      module External
        class << self
          private

          attr_accessor :impl, :enabled
          alias_method :enabled?, :enabled
          public :enabled?

          public

          def setup
            config = Backend.configuration.hoptoad

            service = if config.service && !config.service.empty?
                        config.service.to_sym
                      else
                        :default
                      end
            self.impl = Impl.load service
            self.enabled = impl.setup(config.api_key)
          end

          def reset
            self.enabled = false
          end

          # delegate methods not overriden to the impl
          (Impl::METHODS - public_instance_methods(false)).each do |m|
            define_method(m) do |*args|
              setup unless enabled?
              impl.public_send m, *args
            end
          end
        end
      end
    end
  end
end
