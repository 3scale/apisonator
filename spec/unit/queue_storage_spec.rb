require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe QueueStorage do
      describe "#connection" do
        let(:configuration) { ThreeScale::Backend::Configuration.new }

        context 'when environment is development' do
          let(:environment) { 'development' }
          subject(:conn)    { QueueStorage.connection(environment, configuration) }

          it 'returns a non sentinel connection' do
            expect(conn.client.sentinel?).to be_false
          end
        end

        context 'when environment is production' do
          let(:environment) { 'production' }
          subject(:conn)    { QueueStorage.connection(environment, configuration) }

          context 'with a invalid configuration' do
            it 'returns an exception' do
              expect { conn }.to raise_error RuntimeError
            end
          end

          context 'with a valid configuration' do
            before do
              configuration.add_section(:queues, :master_name, :sentinels)
              configuration.queues.master_name = 'foo'
              configuration.queues.sentinels   = ['foo']
            end

            it 'returns a sentinel connection' do
              expect(conn.client.sentinel?).to be_true
            end
          end
        end
      end
    end
  end
end
