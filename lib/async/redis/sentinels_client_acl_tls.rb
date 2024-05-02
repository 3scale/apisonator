# frozen_string_literal: true

require 'openssl'
require 'async/redis/sentinels'

module Async
  module Redis
    class SentinelsClientACLTLS < SentinelsClient
      def initialize(master_name, sentinels, role = :master, protocol = Protocol::RESP2, config = {}, **options)
        @master_name = master_name
        @sentinel_endpoints = sentinels.map do |sentinel|
          make_endpoint(sentinel[:host], sentinel[:port], config[:ssl], config[:ssl_params])
        end
        @role = role

        @protocol = protocol
        @config = config
        @pool = connect(**options)
      end

      private

      def resolve_master
        @sentinel_endpoints.each do |sentinel_endpoint|
          client = Client.new(sentinel_endpoint, protocol: @protocol)

          begin
            address = client.call('sentinel', 'get-master-addr-by-name', @master_name)
          rescue Errno::ECONNREFUSED
            next
          end

          return make_endpoint(address[0], address[1], @config[:ssl], @config[:ssl_params]) if address
        end

        nil
      end

      def resolve_slave
        @sentinel_endpoints.each do |sentinel_endpoint|
          client = Client.new(sentinel_endpoint, protocol: @protocol)

          begin
            reply = client.call('sentinel', 'slaves', @master_name)
          rescue Errno::ECONNREFUSED
            next
          end

          slaves = available_slaves(reply)
          next if slaves.empty?

          slave = select_slave(slaves)
          return make_endpoint(slave['ip'], slave['port'], @config[:ssl], @config[:ssl_params])
        end

        nil
      end

      def make_endpoint(host, port, ssl, ssl_params)
        tcp_endpoint = Async::IO::Endpoint.tcp(host, port)

        if ssl
          ssl_context = OpenSSL::SSL::SSLContext.new
          ssl_context.set_params(format_ssl_params(ssl_params))
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
