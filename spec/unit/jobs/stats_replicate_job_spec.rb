require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module Stats
      describe ReplicateJob do
        before do
          ThreeScale::Backend::Worker.new
          Stats::Storage.enable!
          Stats::Storage.activate!
        end

        it 'it saves the changed keys for buckets passed' do
          Stats::Storage.should_receive(:save_changed_keys).with("foo")

          Stats::ReplicateJob.perform "foo", Time.now.getutc.to_f
        end

        it 'can be enqueued' do
          ResqueSpec.reset!
          expect(Stats::ReplicateJob).to have_queue_size_of(0)

          Resque.enqueue(Stats::ReplicateJob, "foo", Time.now.getutc.to_f)
          expect(Stats::ReplicateJob).to have_queue_size_of(1)
        end

      end
    end
  end
end
