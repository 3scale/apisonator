require_relative '../../spec_helper'

RSpec.shared_examples 'job hash is correct' do
  it 'has service_id' do
    expect(job).to include(service_id: service_id)
  end

  it 'has applications' do
    expect(job).to include(applications: applications)
  end

  it 'has metrics' do
    expect(job).to include(metrics: metrics)
  end

  it 'has from' do
    expect(job).to include(from: from)
  end

  it 'has to' do
    expect(job).to include(to: to)
  end
end

RSpec.shared_examples 'validation error' do
  it 'raise validation error' do
    expect { subject }.to raise_error(ThreeScale::Backend::DeleteServiceStatsValidationError)
  end
end

RSpec.describe ThreeScale::Backend::Stats::DeleteJobDef do
  let(:service_id) { 'some_service_id' }
  let(:applications) { %w[1 2 3] }
  let(:metrics) { %w[10 20 30] }
  let(:from) { Time.new(2002, 10, 31).to_i }
  let(:to) { Time.new(2003, 10, 31).to_i }
  let(:params) do
    {
      service_id: service_id,
      applications: applications,
      metrics: metrics,
      from: from,
      to: to
    }
  end
  subject { described_class.new params }

  context '#initialize' do
    context 'happy path' do
      it 'does not raise' do should_not be_nil end
    end

    context 'from field is nil' do
      let(:from) { nil }
      include_examples 'validation error'
    end

    context 'from field is string' do
      let(:from) { '12345' }
      include_examples 'validation error'
    end

    context 'from field is zero' do
      let(:from) { 0 }
      include_examples 'validation error'
    end

    context 'to field is nil' do
      let(:to) { nil }
      include_examples 'validation error'
    end

    context 'to field is string' do
      let(:to) { '12345' }
      include_examples 'validation error'
    end

    context 'to field is zero' do
      let(:to) { 0 }
      include_examples 'validation error'
    end

    context 'to field happens before from field' do
      let(:from) { Time.new(2005, 10, 31).to_i }
      let(:to) { Time.new(2003, 10, 31).to_i }
      include_examples 'validation error'
    end

    context 'applicatoins field is nil' do
      let(:applications) { nil }
      include_examples 'validation error'
    end

    context 'applicatoins field is not array' do
      let(:applications) { 3 }
      include_examples 'validation error'
    end

    context 'applicatoins field constains bad element' do
      let(:applications) { ['3', {}, '4'] }
      include_examples 'validation error'
    end

    context 'metrics field is nil' do
      let(:metrics) { nil }
      include_examples 'validation error'
    end

    context 'metrics field is not array' do
      let(:metrics) { 3 }
      include_examples 'validation error'
    end

    context 'metrics field constains element bad string' do
      let(:metrics) { ['3', [], '4'] }
      include_examples 'validation error'
    end
  end

  context '#run_async' do
    before do
      ResqueSpec.reset!
    end

    it 'partition generator job is queued' do
      subject.run_async
      expect(ThreeScale::Backend::Stats::PartitionGeneratorJob).to have_queued(anything,
                                                                               service_id,
                                                                               applications,
                                                                               metrics,
                                                                               from, to, nil)
    end
  end

  context '#to_json' do
    let(:job) { JSON.parse(subject.to_json, symbolize_names: true) }
    include_examples 'job hash is correct'
  end

  context '#to_hash' do
    let(:job) { subject.to_hash }
    include_examples 'job hash is correct'
  end
end
