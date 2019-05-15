require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe QueueStorage do
      describe "#connection" do
        let(:configuration) { ThreeScale::Backend::Configuration::Loader.new }

        context 'when environment is development' do
          let(:environment) { 'development' }
          subject(:conn)    { QueueStorage.connection(environment, configuration) }

          it 'returns a non sentinel connection' do
            connector = conn.instance_variable_get(:@client).instance_variable_get(:@connector)
            expect(connector).to_not be_an_instance_of(Redis::Client::Connector::Sentinel)
          end
        end

        context 'when environment is production' do
          let(:environment) { 'production' }
          subject(:conn)    { QueueStorage.connection(environment, configuration) }

          context 'with a invalid configuration' do
            it 'returns an exception' do
              expect { conn }.to raise_error(StandardError)
            end
          end

          context 'with a valid configuration' do
            before do
              configuration.add_section(:queues, :master_name, :sentinels,
                                        :connect_timeout, :read_timeout, :write_timeout)
              configuration.queues.master_name = 'foo'
              configuration.queues.sentinels   = 'foo'
            end

            it 'returns a sentinel connection' do
              connector = conn.instance_variable_get(:@client).instance_variable_get(:@connector)
              expect(connector).to be_an_instance_of(Redis::Client::Connector::Sentinel)
            end
          end
        end
      end
    end
  end
end
