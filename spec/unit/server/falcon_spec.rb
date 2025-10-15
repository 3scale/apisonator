require 'spec_helper'
require '3scale/backend/server/falcon'

describe ThreeScale::Backend::Server::Falcon do
  describe '.start' do
    let(:global_options) { { manifest: { server_model: { workers: 1 } } } }

    around do |example|
      ENV.delete('FALCON_HOST')
      ENV.delete('FALCON_PORT')
      example.run
      ENV.delete('FALCON_HOST')
      ENV.delete('FALCON_PORT')
    end

    it 'sets FALCON_HOST environment variable when bind is specified' do
      options = { bind: '127.0.0.1' }

      described_class.start(global_options, options, [])

      expect(ENV['FALCON_HOST']).to eq('127.0.0.1')
      expect(ENV['FALCON_PORT']).to be_nil
    end

    it 'sets FALCON_PORT environment variable when port is specified' do
      options = { port: '3001' }

      described_class.start(global_options, options, [])

      expect(ENV['FALCON_HOST']).to be_nil
      expect(ENV['FALCON_PORT']).to eq('3001')
    end

    it 'sets both FALCON_HOST and FALCON_PORT when both are specified' do
      options = { bind: '192.168.1.100', port: '8080' }

      described_class.start(global_options, options, [])

      expect(ENV['FALCON_HOST']).to eq('192.168.1.100')
      expect(ENV['FALCON_PORT']).to eq('8080')
    end
  end
end
