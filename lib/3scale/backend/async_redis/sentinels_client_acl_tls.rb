# frozen_string_literal: true

require 'openssl'
require 'async/redis/sentinels'

module ThreeScale
  module Backend
    module AsyncRedis
      class SentinelsClientACLTLS < Async::Redis::SentinelsClient
        def initialize(uri, protocol = Async::Redis::Protocol::RESP2, config, **options)
          @master_name = uri.host
          @sentinel_endpoints = config[:sentinels].map do |sentinel|
            EndpointHelpers.prepare_endpoint(sentinel[:host], sentinel[:port], config[:ssl], config[:ssl_params])
          end
          @role = config[:role] || :master

          @protocol = protocol
          @config = config
          @pool = connect(**options)
        end

        private

        def resolve_master
          @sentinel_endpoints.each do |sentinel_endpoint|
            client = Async::Redis::Client.new(sentinel_endpoint, protocol: Protocol::ExtendedRESP2.new(credentials: @protocol.credentials))

            begin
              address = client.call('sentinel', 'get-master-addr-by-name', @master_name)
            rescue Errno::ECONNREFUSED
              next
            end

            return EndpointHelpers.prepare_endpoint(address[0], address[1], @config[:ssl], @config[:ssl_params]) if address
          end

          nil
        end

        def resolve_slave
          @sentinel_endpoints.each do |sentinel_endpoint|
            client = Async::Redis::Client.new(sentinel_endpoint, protocol: Protocol::ExtendedRESP2.new(credentials: @protocol.credentials))

            begin
              reply = client.call('sentinel', 'slaves', @master_name)
            rescue Errno::ECONNREFUSED
              next
            end

            slaves = available_slaves(reply)
            next if slaves.empty?

            slave = select_slave(slaves)
            return EndpointHelpers.prepare_endpoint(slave['ip'], slave['port'], @config[:ssl], @config[:ssl_params])
          end

          nil
        end
      end
    end
  end
end
