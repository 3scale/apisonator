# frozen_string_literal: true

# Based on https://github.com/socketry/async-redis/blob/v0.8.1/examples/auth/wrapper.rb

require 'async/redis/client'
require 'async/redis/sentinel_client'
require '3scale/backend/async_redis/endpoint_helpers'

module ThreeScale
  module Backend
    module AsyncRedis
      # Friendly client wrapper that supports SSL, AUTH and db SELECT
      class Client
        class << self
          # @param opts [Hash] Redis connection options
          # @return [Async::Redis::Client]
          # @return [Async::Redis::SentinelClient]
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

            database = uri.path[1..-1]
            credentials = [
              uri.user.to_s.empty? ? opts[:username] : uri.user,
              uri.password.to_s.empty? ? opts[:password] : uri.password
            ].compact
            credentials = nil unless credentials.any?
            ssl = opts[:ssl]
            ssl_params = opts[:ssl_params]
            limit = opts[:max_connections]

            if opts.key? :sentinels
              ssl_context = EndpointHelpers.create_ssl_context(ssl:, ssl_params:)

              master_options = {database:, credentials:, ssl_context:}.compact
              master_name = uri.host
              role = opts[:role] || :master
              endpoints = opts[:sentinels].map do |sentinel|
                host = sentinel[:host]
                port = sentinel[:port]
                sentinel_credentials = [opts[:sentinel_username], opts[:sentinel_password]].compact
                sentinel_credentials = nil unless sentinel_credentials.any?
                EndpointHelpers.prepare_endpoint(host:, port:, credentials: sentinel_credentials, ssl:, ssl_params:)
              end

              Async::Redis::SentinelClient.new(endpoints, master_name:, master_options:, role:, limit:)
            else
              host = uri.host || EndpointHelpers::DEFAULT_HOST
              port = uri.port || EndpointHelpers::DEFAULT_PORT
              endpoint = EndpointHelpers.prepare_endpoint(host:, port:, database:, credentials:, ssl:, ssl_params:)
              Async::Redis::Client.new(endpoint, limit:)
            end
          end

          def connect_unix(opts)
            path = opts[:path]

            credentials = [opts[:username], opts[:password]]
            protocol = Async::Redis::Protocol::RESP2
            protocol = Async::Redis::Protocol::Authenticated.new(credentials, protocol) if credentials.any?
            limit = opts[:max_connections]

            if opts.key? :sentinels
              raise InvalidURI.new(path, 'unix paths are not supported for sentinels')
            else
              endpoint = EndpointHelpers.prepare_endpoint(path: path, ssl: opts[:ssl], ssl_params: opts[:ssl_params])
              Async::Redis::Client.new(endpoint, protocol:, limit:)
            end
          end
        end
      end
    end
  end
end
