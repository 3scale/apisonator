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
            return connect_tcp(opts) if url_present?(opts[:url])

            connect_unix(opts)
          end
          alias :connect :call

          private

          def url_present?(url)
            !url.to_s.strip.empty?
          end

          def connect_tcp(opts)
            uri = URI(opts[:url])

            credentials = [ uri.user || opts[:username], uri.password || opts[:password]]
            db = uri.path[1..-1]

            protocol = Protocol::ExtendedRESP2.new(db: db, credentials: credentials)

            if opts.key? :sentinels
              SentinelsClientACLTLS.new(uri, protocol, opts)
            else
              host = uri.host || EndpointHelpers::DEFAULT_HOST
              port = uri.port || EndpointHelpers::DEFAULT_PORT
              endpoint = EndpointHelpers.prepare_endpoint(host: host, port: port, ssl: opts[:ssl], ssl_params: opts[:ssl_params])
              Async::Redis::Client.new(endpoint, protocol: protocol, limit: opts[:max_connections])
            end
          end

          def connect_unix(opts)
            path = opts[:path]

            credentials = [opts[:username], opts[:password]]
            protocol = Protocol::ExtendedRESP2.new(credentials: credentials)

            if opts.key? :sentinels
              raise InvalidURI.new(path, 'unix paths are not supported for sentinels')
            else
              endpoint = EndpointHelpers.prepare_endpoint(path: path, ssl: opts[:ssl], ssl_params: opts[:ssl_params])
              Async::Redis::Client.new(endpoint, protocol: protocol, limit: opts[:max_connections])
            end
          end
        end
      end
    end
  end
end
