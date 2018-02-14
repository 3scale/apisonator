require '3scale/backend/environment'
require '3scale/backend/configuration'

module ThreeScale
  module Backend
    module Logging
      module External
        module Impl
          module Airbrake
            class << self
              def setup(api_key)
                do_require

                configure api_key
              end

              def setup_rack(rack)
                rack.use middleware
              end

              def setup_rake
                require 'airbrake/tasks'
                require 'airbrake/rake_handler'

                ::Airbrake.configure do |config|
                  config.rescue_rake_exceptions = true
                end
              end

              def setup_worker
                require '3scale/backend/logging/external/resque'

                External::Resque.setup klass
              end

              def notify_proc
                klass.method(:notify).to_proc
              end

              private

              def do_require
                require 'airbrake'
              end

              def klass
                ::Airbrake
              end

              def middleware
                ::Airbrake::Sinatra
              end

              def configure(api_key)
                ::Airbrake.configure do |config|
                  config.api_key = api_key
                  config.environment_name = Backend.environment
                end
              end
            end
          end
        end
      end
    end
  end
end
