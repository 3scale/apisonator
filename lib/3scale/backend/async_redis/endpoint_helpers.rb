# frozen_string_literal: true

require 'async/io'

module ThreeScale
  module Backend
    module AsyncRedis
      module EndpointHelpers

        DEFAULT_HOST = 'localhost'.freeze
        DEFAULT_PORT = 6379

        class << self

          # @param host [String]
          # @param port [String]
          # @param ssl_params [Hash]
          # @return [Async::IO::Endpoint::Generic]
          def prepare_endpoint(host, port, ssl = false, ssl_params = nil)
            tcp_endpoint = Async::IO::Endpoint.tcp(host, port)

            if ssl
              ssl_context = OpenSSL::SSL::SSLContext.new
              ssl_context.set_params(format_ssl_params(ssl_params)) if ssl_params
              return Async::IO::SSLEndpoint.new(tcp_endpoint, ssl_context: ssl_context)
            end

            tcp_endpoint
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
        end
      end
    end
  end
end
