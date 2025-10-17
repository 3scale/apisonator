require 'net/http'
require '3scale/backend'
require_relative '../spec_helpers/listener_server_helper'

module ThreeScale
  module Backend
    describe Listener do
      include ListenerServerHelper

      describe 'maximum_line_length for Falcon' do
        if ThreeScale::Backend.configuration.redis.async
          let(:bind_address) { '127.0.0.1' }
          let(:status_endpoint) { '/status' }
          let(:path) { ->(length) { status_endpoint + '?' + 'key=' + 'a' * (length - status_endpoint.length - 5) } }

          before do
            @port = find_free_port
            start_listener_server(port: @port, server: :falcon, bind: bind_address)
          end

          after do
            stop_listener_server(@port, :falcon, bind_address)
          end

          it 'accepts requests with path under the configured maximum line length (12KB)' do
            response = make_http_request(bind_address, @port, path[10_000])

            expect(response).to be_a(Net::HTTPSuccess)
            expect(response.code).to eq('200')
          end

          it 'rejects requests with path exceeding the configured maximum line length (12KB)' do
            expect {
              make_http_request(bind_address, @port, path[13_000], 5)
            }.to raise_error(EOFError)
          end
        else
          it 'is skipped when not running in async mode (Puma)' do
            skip 'This test only runs with Falcon (async mode)'
          end
        end
      end
    end
  end
end
