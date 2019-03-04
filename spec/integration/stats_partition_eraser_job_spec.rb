require_relative '../spec_helper'

RSpec.describe ThreeScale::Backend::Stats::PartitionEraserJob do
  let(:service_id) { '123456' }
  let(:applications) { %w[1] }
  let(:metrics) { %w[10] }
  let(:users) { %w[] }
  let(:from) { Time.new(2002, 11, 31).to_i }
  let(:to) { from }
  let(:offset) { 5 }
  let(:length) { 10 }
  let(:job_params) do
    {
      service_id: service_id,
      applications: applications,
      metrics: metrics,
      users: users,
      from: from,
      to: to
    }
  end
  let(:stats_queue) { :stats }
  let(:storage) { ThreeScale::Backend::Storage.instance }
  let(:keys) { ThreeScale::Backend::Stats::KeyGenerator.new(job_params).keys }

  before :each do
    # populate all keys
    keys.each { |key| storage.set(key, 1) }
  end

  it 'partition keys are deleted' do
    without_resque_spec do
      Resque.enqueue(described_class, Time.now.getutc.to_f, service_id, applications,
                     metrics, users, from, to, offset, length, nil)
      expect(Resque.size(stats_queue)).to eq 1
      # Try to process the job.
      ThreeScale::Backend::Worker.work(one_off: true)
      expect(keys.drop(offset).take(length).count).to be > 0
      keys_to_be_deleted = keys.drop(offset).take(length)
      expect(keys_to_be_deleted.none? { |key| storage.exists(key) })
    end
  end

  it 'keys outside partition are not deleted' do
    without_resque_spec do
      Resque.enqueue(described_class, Time.now.getutc.to_f, service_id, applications,
                     metrics, users, from, to, offset, length, nil)
      expect(Resque.size(stats_queue)).to eq 1
      # Try to process the job.
      ThreeScale::Backend::Worker.work(one_off: true)
      expected_undeleted_keys = keys.take(offset) + keys.drop(offset + length)
      expect(expected_undeleted_keys.count).to be > 0
      expected_undeleted_keys.each { |key| expect(storage.get(key)).to eq '1' }
    end
  end
end
