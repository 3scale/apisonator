# frozen_string_literal: true

# Based on https://github.com/socketry/async-redis/blob/v0.8.1/examples/auth/wrapper.rb

require 'async/redis/client'
require '3scale/backend/async_redis/endpoint_helpers'
require '3scale/backend/async_redis/sentinels_client_acl_tls'
require '3scale/backend/async_redis/protocol/extended_resp2'

module ThreeScale
  module Backend
    module AsyncRedis
      # Friendly client wrapper that supports SSL, AUTH and db SELECT
      class Client
        class << self
          # @param opts [Hash] Redis connection options
          # @return [Async::Redis::Client]
          def call(opts)
            uri = URI(opts[:url])

            credentials = [ uri.user || opts[:username], uri.password || opts[:password]]
            db = uri.path[1..-1] if uri.path

            protocol = Protocol::ExtendedRESP2.new(db: db, credentials: credentials)

            if opts.key? :sentinels
              SentinelsClientACLTLS.new(uri, protocol, opts)
            else
              host = uri.host || EndpointHelpers::DEFAULT_HOST
              port = uri.port || EndpointHelpers::DEFAULT_PORT
              endpoint = EndpointHelpers.prepare_endpoint(host, port, opts[:ssl], opts[:ssl_params])
              Async::Redis::Client.new(endpoint, protocol: protocol, limit: opts[:max_connections])
            end
          end
          alias :connect :call
        end
      end
    end
  end
end
