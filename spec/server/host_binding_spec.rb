require 'net/http'
require 'socket'
require '3scale/backend'
require_relative '../spec_helpers/listener_server_helper'

module ThreeScale
  module Backend
    describe Listener do
      include ListenerServerHelper

      let(:status_endpoint) { '/status' }

      context 'localhost binding' do
        shared_examples_for 'localhost binding listener' do |server|
          let(:bind_address) { '127.0.0.1' }

          before do
            @port = find_free_port
            start_listener_server(port: @port, server: server, bind: bind_address)
          end

          after do
            stop_listener_server(@port, server, bind_address)
          end

          it 'accepts connections on localhost interface' do
            response = make_http_request('127.0.0.1', @port, status_endpoint)
            expect(response).to be_a(Net::HTTPSuccess)
          end

          it 'rejects connections on external interfaces for security' do
            external_ip = get_external_ip

            # Skip test if we can't determine external IP (containerized environments)
            skip 'Cannot determine external IP' if external_ip.nil? || external_ip.empty?

            expect { make_http_request(external_ip, @port, status_endpoint, 5) }
              .to raise_error(SystemCallError)
          end

          it 'rejects connections on IPv6 localhost' do
            expect { make_http_request('::1', @port, status_endpoint, 5) }
              .to raise_error(SystemCallError)
          end
        end

        if ThreeScale::Backend.configuration.redis.async
          context 'running Falcon' do
            it_behaves_like 'localhost binding listener', :falcon
          end
        else
          context 'running Puma' do
            it_behaves_like 'localhost binding listener', :puma
          end
        end
      end

      context 'default (all interfaces) binding' do
        shared_examples_for 'default binding listener' do |server|
          let(:bind_address) { nil }

          before do
            @port = find_free_port
            start_listener_server(port: @port, server: server, bind: bind_address)
          end

          after do
            stop_listener_server(@port, server, bind_address)
          end

          it 'accepts connections on localhost interface' do
            response = make_http_request('127.0.0.1', @port, status_endpoint)
            expect(response).to be_a(Net::HTTPSuccess)
          end

          it 'accepts connections on external interfaces when available' do
            external_ip = get_external_ip

            # Skip test if we can't determine external IP (containerized environments)
            if external_ip.nil? || external_ip.empty?
              skip 'Cannot determine external IP - may be expected in containerized environment'
            else
              expect { make_http_request(external_ip, @port, status_endpoint, 5) }
                .not_to raise_error
            end
          end
        end

        if ThreeScale::Backend.configuration.redis.async
          context 'running Falcon' do
            it_behaves_like 'default binding listener', :falcon
          end
        else
          context 'running Puma' do
            it_behaves_like 'default binding listener', :puma
          end
        end
      end

      context 'IPv6 localhost binding' do
        shared_examples_for 'ipv6 localhost binding listener' do |server|
          let(:bind_address) { '[::1]' }

          before do
            @port = find_free_port
            start_listener_server(port: @port, server: server, bind: bind_address)
          end

          after do
            stop_listener_server(@port, server, bind_address)
          end

          it 'accepts connections on IPv6 localhost interface' do
            response = make_http_request('::1', @port, status_endpoint)
            expect(response).to be_a(Net::HTTPSuccess)
          end

          it 'rejects connections on IPv4 localhost' do
            expect { make_http_request('127.0.0.1', @port, status_endpoint, 5) }
              .to raise_error(SystemCallError)
          end
        end

        if ThreeScale::Backend.configuration.redis.async
          context 'running Falcon' do
            it_behaves_like 'ipv6 localhost binding listener', :falcon
          end
        else
          context 'running Puma' do
            it_behaves_like 'ipv6 localhost binding listener', :puma
          end
        end
      end

      private

      def get_external_ip
        # Try to get the first non-loopback IP address
        Socket.ip_address_list.find do |addr|
          addr.ipv4? && !addr.ipv4_loopback? && !addr.ipv4_multicast?
        end&.ip_address
      rescue
        nil
      end
    end
  end
end
