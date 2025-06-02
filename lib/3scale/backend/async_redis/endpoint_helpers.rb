# frozen_string_literal: true

require 'async/redis/endpoint'
require 'io/endpoint/ssl_endpoint'
require 'io/endpoint/unix_endpoint'

module ThreeScale
  module Backend
    module AsyncRedis
      module EndpointHelpers

        DEFAULT_HOST = 'localhost'.freeze
        DEFAULT_PORT = 6379

        class << self

          # @param host [String]
          # @param port [Integer]
          # @param path [String]
          # @param database [String]
          # @param credentials [Array]
          # @param ssl [Boolean]
          # @param ssl_params [Hash]
          # @return [Async::IO::Endpoint::Generic]
          def prepare_endpoint(**kwargs)
            host_present?(kwargs[:host]) ? prepare_tcp_endpoint(**kwargs) : prepare_unix_endpoint(**kwargs)
          end

          def create_ssl_context(ssl: false, ssl_params: nil)
            if ssl
              ssl_context = OpenSSL::SSL::SSLContext.new
              ssl_context.set_params(format_ssl_params(ssl_params)) if ssl_params
            end

            ssl_context
          end

          private

          def prepare_tcp_endpoint(host: nil, port: nil, database: nil, credentials: nil, ssl: false, ssl_params: nil)
            ssl_context = create_ssl_context(ssl:, ssl_params:)

            scheme = ssl_context ? 'rediss' : 'redis'
            uri = URI::Generic.build(scheme:, host:, port:)

            Async::Redis::Endpoint.new(uri, nil, database:, credentials:, ssl_context:)
          end

          def prepare_unix_endpoint(path: '', credentials: nil, ssl: false, ssl_params: nil)
            IO::Endpoint.unix(path, Socket::PF_UNIX)
          end

          def format_ssl_params(ssl_params)
            cert = ssl_params[:cert].to_s.strip
            key = ssl_params[:key].to_s.strip
            return ssl_params if cert.empty? && key.empty?

            updated_ssl_params = ssl_params.dup
            updated_ssl_params[:cert] = OpenSSL::X509::Certificate.new(File.read(cert))
            updated_ssl_params[:key] = OpenSSL::PKey.read(File.read(key))

            updated_ssl_params
          end

          def host_present?(host)
            !host.to_s.strip.empty?
          end
        end
      end
    end
  end
end
