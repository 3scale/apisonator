require '3scale/backend/worker_async'

module ThreeScale
  module Backend
    describe WorkerAsync do
      describe '#work' do
        let(:job_fetcher) { instance_double('JobFetcher') }

        describe 'when the one_off option is enabled' do
          subject do
            WorkerAsync.new(one_off: true, job_fetcher: job_fetcher)
          end

          let(:test_job) { instance_double('BackgroundJob') }

          before do
            allow(test_job).to receive(:perform)
            allow(job_fetcher).to receive(:fetch).and_return(test_job)
          end

          it 'processes just one job' do
            subject.work
            expect(test_job).to have_received(:perform)
          end
        end

        describe 'when a job raises' do
          subject do
            WorkerAsync.new(one_off: true, job_fetcher: job_fetcher)
          end

          let(:test_job) { instance_double('BackgroundJob') }
          let(:error) { Exception.new('test error') }

          before do
            allow(test_job).to receive(:perform).and_raise(error)
            allow(test_job).to receive(:fail)
            allow(job_fetcher).to receive(:fetch).and_return(test_job)
          end

          it 'sends fail() to the job' do
            subject.work
            expect(test_job).to have_received(:fail).with(error)
          end
        end
      end
    end
  end
end
