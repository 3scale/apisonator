require 'spec_helper'
require '3scale/backend/server/puma'

describe ThreeScale::Backend::Server::Puma do
  describe '.start' do
    let(:global_options) { { manifest: { server_model: { workers: 1, min_threads: 1, max_threads: 1 } } } }

    it 'includes bind parameter when bind is specified' do
      options = { bind: '127.0.0.1', port: '3000' }
      result = described_class.start(global_options, options, [])

      expect(result).to include('--bind', 'tcp://127.0.0.1:3000')
    end

    it 'uses port-only when no bind specified' do
      options = { port: '3000' }
      result = described_class.start(global_options, options, [])

      expect(result).to include('-p', '3000')
      expect(result).not_to include('--bind')
    end

    it 'includes both bind and port in bind string' do
      options = { bind: '[::1]', port: '8080' }
      result = described_class.start(global_options, options, [])

      expect(result).to include('--bind', 'tcp://[::1]:8080')
    end
  end
end
