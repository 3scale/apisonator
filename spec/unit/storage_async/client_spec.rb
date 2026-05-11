require 'spec_helper'

if ThreeScale::Backend.configuration.redis.async
  module ThreeScale
    module Backend
      module StorageAsync
        describe Client do
          let(:opts) do
            {
              url: 'redis://localhost:6379',
              reconnect_attempts: 2,
              reconnect_wait_seconds: 0,
              max_connections: 10
            }
          end
          let(:client) { described_class.new(opts) }
          let(:fake_conn) { double('async_redis_client') }

          before do
            allow(AsyncRedis::Client).to receive(:connect).and_return(fake_conn)
          end

          describe 'with_reconnect' do
            context 'when a connection error occurs and then recovers' do
              it 'retries without replacing the underlying client' do
                call_count = 0
                allow(fake_conn).to receive(:call) do
                  call_count += 1
                  raise Errno::ECONNRESET if call_count == 1
                  'PONG'
                end

                result = client.call('PING')

                expect(result).to eq('PONG')
                expect(AsyncRedis::Client).to have_received(:connect).once
              end
            end

            context 'when all retry attempts are exhausted' do
              it 'raises the connection error' do
                allow(fake_conn).to receive(:call).and_raise(Errno::ECONNRESET)

                expect { client.call('PING') }.to raise_error(Errno::ECONNRESET)
              end

              it 'does not replace the underlying client between attempts' do
                allow(fake_conn).to receive(:call).and_raise(Errno::ECONNRESET)

                client.call('PING') rescue nil

                expect(AsyncRedis::Client).to have_received(:connect).once
              end
            end

            context 'when multiple fibers fail concurrently' do
              let(:concurrency) { 10 }

              it 'reuses the same client instance across all fibers' do
                failed_fibers = {}
                allow(fake_conn).to receive(:call) do
                  fiber = Fiber.current
                  unless failed_fibers[fiber]
                    failed_fibers[fiber] = true
                    raise Errno::ECONNRESET
                  end
                  'PONG'
                end

                barrier = Async::Barrier.new
                concurrency.times { barrier.async { client.call('PING') } }
                barrier.wait

                expect(AsyncRedis::Client).to have_received(:connect).once
              end
            end
          end
        end
      end
    end
  end
else
  describe 'StorageAsync::Client' do
    it 'is skipped when not running in async mode' do
      skip 'This test only runs in async mode'
    end
  end
end
