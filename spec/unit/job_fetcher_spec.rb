module ThreeScale
  module Backend
    describe JobFetcher do
      before do
        Logging::Worker.configure_logging(Worker, '/dev/null')
      end

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

        it 'async fetches jobs from queues in the order defined (priority > main > stats)' do
          fetch_timeout = 1
          job_fetcher = JobFetcher.new(
            redis_client: test_redis, fetch_timeout: fetch_timeout
          )

          %w[queue:priority queue:main queue:stats].each do |queue|
            expect(test_redis)
              .to receive(:lpop).ordered
              .with(queue, 5)
          end

          job_fetcher.fetch(wait: false, max: 5)
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

        context 'when `wait` is set to true' do
          let(:enqueued_job) { [job_queue, subject.encode(BackgroundJob.new)] }

          it 'calls a blocking redis command' do
            expect(test_redis).to receive(:blpop)
            subject.fetch
          end

          context 'and `max` is nil' do
            it 'returns one job' do
              expect(test_redis).to receive(:blpop).and_return(enqueued_job)
              result = subject.fetch

              expect(result.class).to eq Resque::Job
            end
          end

          context 'and `max` is not nil' do
            it 'returns one job' do
              expect(test_redis).to receive(:blpop).and_return(enqueued_job)
              result = subject.fetch(max: 5)

              expect(result.size).to eq 1
            end
          end
        end

        context 'when `wait` is set to false' do
          let(:enqueued_jobs) {
            [subject.encode(BackgroundJob.new), subject.encode(BackgroundJob.new), subject.encode(BackgroundJob.new)]
          }

          it 'calls a non-blocking redis command' do
            expect(test_redis).to receive(:lpop).at_least(:once)
            subject.fetch(wait: false)
          end

          context 'and `max` is nil' do
            it 'returns one job' do
              expect(test_redis).to receive(:lpop).and_return(enqueued_jobs.slice(0,1))
              result = subject.fetch(wait: false)

              expect(result.class).to eq Resque::Job
            end
          end

          context 'and `max` is not nil' do
             it 'returns up to `max` jobs' do
              expect(test_redis).to receive(:lpop).with(resque_queue, 2).and_return(enqueued_jobs.slice(0,2))
              result = subject.fetch(wait: false, max: 2)

              expect(result.size).to eq 2
            end
          end
        end
      end

      # start is only used in async mode
      describe '#start', if: Backend.configuration.redis.async do
        let(:resque_queue) { 'queue:priority' }
        let(:job_queue) { resque_queue.sub('queue:', '') }

        let(:test_redis) { double }

        subject { JobFetcher.new(redis_client: test_redis) }

        describe 'normal operation' do
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
            # make async worker fall backs to blpop but also give opportunity for cooperative multitasking
            allow(test_redis).to receive(:lpop).with(any_args) { sleep 0.001; nil }
          end

          it 'fetches jobs and puts them in a local queue, closes queue after, does not enqueue nils' do
            queue = Queue.new

            fetching = Async do |task|
              task.with_timeout(200) do
                subject.start(queue)
              end
            end

            Sync do |task|
              task.with_timeout(200) do
                (jobs.size - 1).times do |i|
                  job = queue.pop
                  expect(job.queue).to eq jobs[i].first
                  expect(job.payload).to eq JSON.parse(jobs[i].last)
                end
              end
            end

            subject.shutdown
            fetching.wait

            expect(queue).to be_empty
            expect(queue).to be_closed
          end
        end

        context 'when there is a fetching error or something really weird' do
          let(:error) { RuntimeError.new('Some error') }
          let(:queue) { Queue.new }
          let(:job_fetcher) { JobFetcher.new(redis_client: test_redis) }

          before do
            allow(test_redis).to receive(:blpop).and_raise error
            allow(test_redis).to receive(:lpop).with(any_args).and_raise error
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
