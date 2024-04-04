require '3scale/backend/job_fetcher'

module ThreeScale
  module Backend
    describe JobFetcher do
      describe '#fetch' do
        let(:resque_queue) { 'queue:priority' }
        let(:job_queue) { resque_queue.sub('queue:', '') }

        let(:test_redis) { double }

        subject { JobFetcher.new(redis_client: test_redis) }

        context 'when the arguments of the job do not have encoding issues' do
          let(:enqueued_job) do
            { 'class' => 'ThreeScale::Backend::Transactor::ReportJob',
              'args' => ['100',
                         { '0' => { 'app_id' => '123', 'usage' => { 'hits' => 1 } } },
                         1455783230,
                         { }] }
          end

          let(:job_info) { [resque_queue, subject.encode(enqueued_job)] }

          before do
            allow(test_redis).to receive(:blpop).and_return(job_info)
          end

          it 'returns a job with the correct resque queue and payload' do
            job = subject.fetch
            expect(job.queue).to eq job_queue
            expect(job.payload).to eq enqueued_job
          end
        end

        context 'when the arguments of the job contain invalid UTF8 characters' do
          let(:enqueued_job) do
            "{\"class\":\"ThreeScale::Backend::Transactor::ReportJob\","\
            "\"args\":[\"100\",{\"0\":{\"app_id\":\"123\",\"usage\":{\"hits\":1}}},"\
            "1455783230,{\"log\":\"\xF0\x90\x28\xBC\"}]}"
          end

          let(:job_info) { [resque_queue, enqueued_job] }

          before do
            allow(test_redis).to receive(:blpop).and_return(job_info)
          end

          it 'returns a job with the correct resque queue and payload' do
            job = subject.fetch
            expect(job.queue).to eq job_queue
            expect(job.payload).to eq JSON.parse(enqueued_job)
          end

          it 'does not replace the invalid chars of the job payload' do
            job = subject.fetch
            expect(job.payload.valid_encoding?).to be false
          end
        end

        context 'when the object we get from Resque queue is nil' do
          before { allow(test_redis).to receive(:blpop).and_return(nil) }

          it 'returns nil' do
            expect(subject.fetch).to be nil
          end
        end

        context 'when the object we get from the Resque queue is empty' do
          before { allow(test_redis).to receive(:blpop).and_return([]) }

          it 'returns nil' do
            expect(subject.fetch).to be nil
          end
        end

        context 'when the object we get from the Resque queue is not a well-formed JSON' do
          let(:invalid_enqueued_job) { [resque_queue, '{}}'] }

          before do
            Worker.new # To make sure the workers logging is configured
            allow(test_redis).to receive(:blpop).and_return(invalid_enqueued_job)
            allow(Worker.logger).to receive(:notify)
          end

          it 'returns nil' do
            expect(subject.fetch).to be nil
          end

          it 'notifies the logger' do
            expect(Worker.logger).to receive(:notify)
            subject.fetch
          end
        end

        it 'fetches jobs from queues in the order defined (priority > main > stats)' do
          fetch_timeout = 1
          job_fetcher = JobFetcher.new(
              redis_client: test_redis, fetch_timeout: fetch_timeout
          )

          expect(test_redis)
              .to receive(:blpop)
              .with('queue:priority', 'queue:main', 'queue:stats', timeout: fetch_timeout)

          job_fetcher.fetch
        end

        context 'when there is an error getting elements from the queue' do
          context 'and it is not a connection error' do
            let(:test_error) { RuntimeError.new('Some error') }

            before do
              allow(test_redis).to receive(:blpop).and_raise test_error
            end

            it 'propagates the exception' do
              expect { subject.fetch }.to raise_error test_error
            end
          end
        end
      end

      describe '#start' do
        let(:resque_queue) { 'queue:priority' }
        let(:job_queue) { resque_queue.sub('queue:', '') }

        let(:test_redis) { double }

        subject { JobFetcher.new(redis_client: test_redis) }

        describe 'when the max num of jobs in the local queue is not reached' do
          let(:jobs) do
            [
              [job_queue, subject.encode(BackgroundJob.new)],
              [job_queue, subject.encode(BackgroundJob.new)],
              nil
            ]
          end

          before do
            # This returns the 2 jobs in the 2 first calls, and nil for any
            # call after that.
            allow(test_redis).to receive(:blpop).and_return(*jobs)
          end

          it 'fetches jobs and puts them in a local queue' do
            queue = Queue.new
            t = Thread.new { subject.start(queue) }

            (jobs.size - 1).times do |i|
              job = queue.pop
              expect(job.queue).to eq jobs[i].first
              expect(job.payload).to eq JSON.parse(jobs[i].last)
            end

            subject.shutdown
            t.join
          end
        end

        context 'when there is an error not related with Redis connectivity' do
          let(:error) { Exception.new('Some error') }
          let(:queue) { Queue.new }
          let(:job_fetcher) { JobFetcher.new(redis_client: test_redis) }

          before do
            allow(test_redis).to receive(:blpop).and_raise error
            allow(Worker.logger).to receive(:notify)
          end

          it 'closes the queue' do
            Thread.new { job_fetcher.start(queue) }.join

            expect(queue.closed?).to be true
          end

          it 'notifies the error' do
            Thread.new { job_fetcher.start(queue) }.join

            expect(Worker.logger).to have_received(:notify).with(error)
          end
        end
      end
    end
  end
end
