# This is a module to configure an external error logging service for Resque.
#
# The requirement is that an object be passed in that implements the same
# interface as Airbrake.
#
# This requires a Resque version with https://github.com/resque/resque/pull/1602
#
module ThreeScale
  module Backend
    module Logging
      module External
        module Resque
          class << self
            def setup(klass)
              load_resque_failure_for klass

              ::Resque::Failure::Multiple.classes = [
                ::Resque::Failure::Redis,
                Class.new(::Resque::Failure::Airbrake) do
                  def self.configure(&block)
                    # calling this hook is an error
                    raise "error: tried to configure #{self.inspect} from Resque"
                  end
                end,
              ]
              ::Resque::Failure.backend = ::Resque::Failure::Multiple
            end

            private

            # set the argument as ::Airbrake and load Resque::Failure
            def load_resque_failure_for(klass)
              require 'resque/failure/base'
              require 'resque/failure/multiple'
              require 'resque/failure/redis'

              # ensure we have a matching ::Airbrake top-level constant or
              # define it if missing
              begin
                airbrake = ::Kernel.const_get(:Airbrake)
              rescue NameError
                # not defined, so set our own
                ::Kernel.const_set(:Airbrake, klass)
              else
                # defined, expect it's our own object
                raise "Airbrake constant pre-defined as #{airbrake.inspect}, " \
                      " required to be #{klass.inspect}!" if airbrake != klass
              end

              require 'resque/failure/airbrake'
            end
          end
        end
      end
    end
  end
end
