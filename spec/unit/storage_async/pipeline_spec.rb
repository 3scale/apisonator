require '3scale/backend/storage_async'

module ThreeScale
  module Backend
    module StorageAsync
      describe Pipeline do
        describe '.run' do
          let(:storage) {ThreeScale::Backend::StorageAsync::Client.instance(true)}
          let(:async_client) { storage.instance_variable_get(:@inner).instance_variable_get(:@redis_async) }

          subject { Pipeline.new }

          # Spec helpers make sure to cleanup instances of Storage, but in this
          # case, we are using the client directly with a host/port so we need
          # this to call flushdb().
          before { storage.flushdb }

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

          context 'When a fiber that is not the one that created the pipeline adds commands' do
            it 'raises an error' do
              pipeline = nil
              Fiber.new { pipeline = Pipeline.new }.resume
              expect { Fiber.new { pipeline.call('GET', 'some_key') }.resume }
                  .to raise_error Pipeline::PipelineSharedBetweenFibers
            end
          end
        end
      end
    end
  end
end
