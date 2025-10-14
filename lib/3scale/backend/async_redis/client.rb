# frozen_string_literal: true

# Based on https://github.com/socketry/async-redis/blob/v0.8.1/examples/auth/wrapper.rb

require 'async/redis/client'
require 'async/redis/sentinel_client'

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
            ssl_context = create_ssl_context(ssl: opts[:ssl], ssl_params: opts[:ssl_params])
            limit = opts[:max_connections]

            if opts.key? :sentinels
              master_options = {database:, credentials:, ssl_context:}.compact
              master_name = uri.host
              role = opts[:role] || :master
              endpoints = opts[:sentinels].map do |sentinel|
                sentinel_credentials = [opts[:sentinel_username], opts[:sentinel_password]].compact
                sentinel_credentials = nil unless sentinel_credentials.any?
                Async::Redis::Endpoint.for(nil, sentinel[:host], port: sentinel[:port],
                                           credentials: sentinel_credentials, ssl_context:)
              end

              Async::Redis::SentinelClient.new(endpoints, master_name:, master_options:, role:, limit:)
            else
              endpoint = Async::Redis::Endpoint.new(uri, nil, database:, credentials:, ssl_context:)
              Async::Redis::Client.new(endpoint, limit:)
            end
          end

          def connect_unix(opts)
            path = opts[:path]

            credentials = [opts[:username], opts[:password]]
            credentials = nil unless credentials.any?
            limit = opts[:max_connections]

            if opts.key? :sentinels
              raise InvalidURI.new(path, 'unix paths are not supported for sentinels')
            else
              endpoint = Async::Redis::Endpoint.unix(path, credentials:)
              Async::Redis::Client.new(endpoint, limit:)
            end
          end

          def create_ssl_context(ssl: false, ssl_params: nil)
            if ssl
              ssl_context = OpenSSL::SSL::SSLContext.new
              if ssl_params
                cert_path = ssl_params.delete(:cert).to_s.strip
                key_path = ssl_params.delete(:key).to_s.strip

                if !cert_path.empty? && !key_path.empty?
                  # Client certificate with key - use add_certificate
                  cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
                  key = OpenSSL::PKey.read(File.read(key_path))
                  ssl_context.add_certificate(cert, key)
                end

                ssl_context.set_params(ssl_params)
              end
            end

            ssl_context
          end
        end
      end
    end
  end
end
