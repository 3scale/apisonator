require_relative '../spec_helper'

RSpec.describe ThreeScale::Backend::Stats::PartitionGeneratorJob do
  include SpecHelpers::WorkerHelper

  let(:service_id) { '123456' }
  let(:applications) { %w[1] }
  let(:metrics) { %w[10] }
  let(:from) { Time.new(2002, 10, 31).to_i }
  let(:to) { Time.new(2002, 11, 30).to_i }
  let(:job) do
    ThreeScale::Backend::Stats::DeleteJobDef.new(
      service_id: service_id,
      applications: applications,
      metrics: metrics,
      from: from,
      to: to
    )
  end
  let(:stats_queue) { :stats }
  let(:configuration) { ThreeScale::Backend.configuration }
  let(:num_keys_generated) { ThreeScale::Backend::Stats::KeyGenerator.new(job).keys.count }

  before :each do
    configuration.stats.delete_partition_batch_size = 100
  end

  it 'expected number of resque jobs are generated' do
    without_resque_spec do
      job.run_async
      expect(Resque.size(stats_queue)).to eq 1
      process_one_job
      expect(Resque.size(stats_queue)).to eq((num_keys_generated.to_f / configuration.stats.delete_partition_batch_size).ceil)
    end
  end
end
