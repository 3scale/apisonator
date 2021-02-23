require '3scale/backend/configuration'
require '3scale/backend/logging/middleware'
require '3scale/backend/util'
require '3scale/backend/rack/exception_catcher'
require '3scale/backend/rack/prometheus'
require '3scale/backend/rack/internal_error_catcher'
require '3scale/backend'

require 'rack'

module ThreeScale
  module Backend
    module Rack
      def self.run(rack)
        rack.instance_eval do
          use Rack::InternalErrorCatcher if Backend.production?

          Backend::Logging::External.setup_rack self

          # Notice that this cannot be specified via config, it needs to be an
          # ENV because the metric server is started in Puma/Falcon
          # "before_fork" and the configuration is not loaded at that point.
          if ENV['CONFIG_LISTENER_PROMETHEUS_METRICS_ENABLED'].to_s.downcase.freeze == 'true'.freeze
            use Rack::Prometheus
          end

          loggers = Backend.configuration.request_loggers
          log_writers = Backend::Logging::Middleware.writers loggers
          use Backend::Logging::Middleware, writers: log_writers

          map "/internal" do
            require_relative "#{Backend::Util.root_dir}/app/api/api"

            internal_api = Backend::API::Internal.new(
              username: Backend.configuration.internal_api.user,
              password: Backend.configuration.internal_api.password,
              allow_insecure: !Backend.production?
            )

            use ::Rack::Auth::Basic do |username, password|
              internal_api.helpers.check_password username, password
            end if internal_api.helpers.credentials_set?

            run internal_api
          end

          run Backend::Listener.new
        end
      end
    end
  end
end
