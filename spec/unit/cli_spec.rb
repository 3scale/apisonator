require 'spec_helper'

# Load the Runner class from the CLI script without executing it
load File.expand_path('../../bin/3scale_backend', __dir__)

describe 'CLI argument parsing' do
  describe 'bind parameter parsing' do
    let(:mock_server) { double('server') }

    before do
      allow(ThreeScale::Backend::Server).to receive(:get).and_return(mock_server)
      allow(Runner).to receive(:exec) # Prevent actual process execution
    end

    it 'passes bind parameter to server start method' do
      received_opts = nil
      expect(mock_server).to receive(:start) do |_global_opts, opts, _args|
        received_opts = opts
        ['mocked', 'command']
      end

      Runner.run(['-n', 'start', '--bind', '127.0.0.1', '-p', '3001'])

      expect(received_opts[:bind]).to eq('127.0.0.1')
      expect(received_opts[:port]).to eq('3001')
    end

    it 'passes IPv6 bind parameter correctly' do
      received_opts = nil
      expect(mock_server).to receive(:start) do |_global_opts, opts, _args|
        received_opts = opts
        ['mocked', 'command']
      end

      Runner.run(['-n', 'start', '--bind', '[::1]', '-p', '3001'])

      expect(received_opts[:bind]).to eq('[::1]')
      expect(received_opts[:port]).to eq('3001')
    end

    it 'uses default bind value when not specified' do
      received_opts = nil
      expect(mock_server).to receive(:start) do |_global_opts, opts, _args|
        received_opts = opts
        ['mocked', 'command']
      end

      Runner.run(['-n', 'start', '-p', '3001'])

      expect(received_opts[:bind]).to eq('0.0.0.0')
      expect(received_opts[:port]).to eq('3001')
    end

    it 'passes bind parameter with different addresses' do
      test_addresses = ['192.168.1.100', 'localhost', '0.0.0.0', '[::]']

      test_addresses.each do |address|
        received_opts = nil
        expect(mock_server).to receive(:start) do |_global_opts, opts, _args|
          received_opts = opts
          ['mocked', 'command']
        end

        Runner.run(['-n', 'start', '--bind', address, '-p', '3001'])

        expect(received_opts[:bind]).to eq(address)
        expect(received_opts[:port]).to eq('3001')
      end
    end
  end

  describe 'argument validation' do
    let(:mock_server) { double('server') }

    before do
      allow(ThreeScale::Backend::Server).to receive(:get).and_return(mock_server)
      allow(Runner).to receive(:exec) # Prevent actual process execution
    end

    it 'accepts valid bind addresses and passes them to server' do
      valid_addresses = ['127.0.0.1', '[::1]', 'localhost', '0.0.0.0', '[::]', '192.168.1.100']

      valid_addresses.each do |address|
        received_opts = nil
        expect(mock_server).to receive(:start) do |_global_opts, opts, _args|
          received_opts = opts
          ['mocked', 'command']
        end

        expect {
          Runner.run(['-n', 'start', '--bind', address, '-p', '3001'])
        }.not_to raise_error

        expect(received_opts[:bind]).to eq(address)
        expect(received_opts[:port]).to eq('3001')
      end
    end
  end
end
