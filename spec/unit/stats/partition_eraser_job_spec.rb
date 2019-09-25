require_relative '../../spec_helper'

RSpec.describe ThreeScale::Backend::Stats::PartitionEraserJob do
  let(:service_id) { '123456' }
  let(:applications) { %w[] }
  let(:metrics) { %w[] }
  let(:from) { Time.new(2002, 10, 31).to_i }
  let(:to) { Time.new(2002, 11, 30).to_i }
  let(:offset) { 5 }
  let(:length) { 10 }

  subject do
    described_class.perform_logged(nil, service_id, applications, metrics, from, to,
                                   offset, length, nil)
  end

  context 'offset is invalid' do
    let(:offset) { 'd' }

    it 'returns error' do
      ok, msg = subject
      expect(ok).to be_falsey
      expect(msg).to include('offset field value')
    end
  end

  context 'length is invalid' do
    let(:length) { 'd' }

    it 'returns error' do
      ok, msg = subject
      expect(ok).to be_falsey
      expect(msg).to include('length field value')
    end
  end

  context 'job param is invalid' do
    let(:metrics) { 'd' }

    it 'returns error' do
      ok, msg = subject
      expect(ok).to be_falsey
      expect(msg).to include('metrics field')
    end
  end
end
