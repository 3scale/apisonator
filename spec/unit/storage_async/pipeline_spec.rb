require '3scale/backend/storage_async'

module ThreeScale
  module Backend
    module StorageAsync
      describe Pipeline do
        describe '.run' do
          let(:endpoint) { Async::IO::Endpoint.tcp('localhost', 6379) }
          let(:async_client) { Async::Redis::Client.new(endpoint) }

          subject { Pipeline.new }

          # Spec helpers make sure to cleanup instances of Storage, but in this
          # case, we are using the client directly with a host/port so we need
          # this to call flushdb().
          before { async_client.flushdb! }

          context 'When the list of commands is empty' do
            it 'returns an empty array' do
              expect(subject.run(async_client)).to be_empty
            end
          end

          context 'When the list of commands is not empty' do
            it 'returns an array with the responses in the same order' do
              subject.call('GET', 'some_key')
              subject.call('SET', 'some_key', '1')
              subject.call('GET', 'some_key')

              expect(subject.run(async_client)).to eq([nil, 'OK', '1'])
            end
          end
        end
      end
    end
  end
end
