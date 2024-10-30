# frozen_string_literal: true

require 'async/io'
require 'async/io/unix_endpoint'

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
          # @param ssl [Boolean]
          # @param ssl_params [Hash]
          # @return [Async::IO::Endpoint::Generic]
          def prepare_endpoint(**kwargs)
            host_present?(kwargs[:host]) ? prepare_tcp_endpoint(**kwargs) : prepare_unix_endpoint(**kwargs)
          end

          private

          def prepare_tcp_endpoint(host: nil, port: nil, ssl: false, ssl_params: nil)
            tcp_endpoint = Async::IO::Endpoint.tcp(host, port)

            return prepare_ssl_endpoint(endpoint: tcp_endpoint, ssl_params: ssl_params) if ssl

            tcp_endpoint
          end

          def prepare_unix_endpoint(path: '', ssl: false, ssl_params: nil)
            unix_endpoint = Async::IO::Endpoint.unix(path, Socket::PF_UNIX)
            return unix_endpoint unless ssl

            prepare_ssl_endpoint(endpoint: unix_endpoint, ssl_params: ssl_params)
          end

          def prepare_ssl_endpoint(endpoint: nil, ssl_params: nil)
            ssl_context = OpenSSL::SSL::SSLContext.new
            ssl_context.set_params(format_ssl_params(ssl_params)) if ssl_params
            Async::IO::SSLEndpoint.new(endpoint, ssl_context: ssl_context)
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
