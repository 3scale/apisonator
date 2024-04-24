module ThreeScale
  module Backend
    context 'when failed jobs are rescheduled' do
      include SpecHelpers::WorkerHelper

      let(:provider_key) { 'a_provider_key' }
      let(:service_id) { 'a_service_id' }
      let(:app_id) { 'an_app_id' }
      let(:metric_id) { 'a_metric_id' }
      let(:metric_name) { 'hits' }

      # We are going to enqueue a report job. And those are enqueued the
      # 'priority' queue.
      let(:queue) { 'priority' }

      before do
        Service.save!(provider_key: provider_key, id: service_id)

        Application.save(service_id: service_id,
                         id: app_id,
                         state: :active)

        Metric.save(service_id: service_id,
                    id: metric_id,
                    name: metric_name)

        # Any kind of background job is going to fail
        allow_any_instance_of(Resque::Job)
            .to receive(:perform)
            .and_raise(Exception.new)
      end

      after do
        Resque.remove_queue(queue)
      end

      it 'they are queued in the same queue they were the first time' do
        without_resque_spec do
          # Enqueue a report job
          Transactor.report(provider_key,
                            service_id,
                            0 => { 'app_id' => app_id,
                                   'usage'  => { metric_name => 1 } })

          expect(Resque.size(queue)).to eq 1

          # Try to process the job. It will fail and will be moved to the
          # failed jobs queue.
          process_one_job
          expect(Resque.size(queue)).to be_zero
          expect(Resque::Failure.count).to eq 1

          # Reschedule the job. Check that it left the failed jobs queue and
          # was queued into its original queue.
          FailedJobsScheduler.reschedule_failed_jobs
          expect(Resque.size(queue)).to eq 1
          expect(Resque::Failure.count).to be_zero
        end
      end
    end
  end
end
