require '3scale/backend/version'
require '3scale/backend/environment'
require '3scale/backend/util'
require '3scale/backend/logging'

module ThreeScale
  module Backend
    module Logging
      module External
        module Impl
          module Bugsnag
            class << self
              def setup(api_key)
                do_require

                configure api_key
              end

              def setup_rack(rack)
                rack.use middleware
              end

              def setup_rake
                # no-op
              end

              def setup_worker
                # Bugsnag should integrate automatically with Resque
              end

              def notify_proc
                klass.method(:notify).to_proc
              end

              private

              def do_require
                require 'bugsnag'
              end

              def klass
                ::Bugsnag
              end

              def middleware
                ::Bugsnag::Rack
              end

              def configure(api_key)
                ::Bugsnag.configure do |config|
                  config.api_key = api_key
                  config.release_stage = Backend.environment
                  config.app_version = Backend::VERSION
                  config.timeout = 3
                  config.logger = Backend.logger
                  config.meta_data_filters = []
                  config.enabled_release_stages = %w[production staging development]
                  config.project_root = Backend::Util.root_dir
                end
              end
            end
          end
        end
      end
    end
  end
end
