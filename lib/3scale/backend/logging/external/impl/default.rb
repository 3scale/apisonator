module ThreeScale
  module Backend
    module Logging
      module External
        module Impl
          # the default implementation does nothing
          class Default
            class << self
              (Impl::METHODS - public_instance_methods(false)).each do |m|
                define_method(m) { |*| }
              end
            end
          end
        end
      end
    end
  end
end
