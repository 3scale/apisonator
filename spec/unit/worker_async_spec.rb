require '3scale/backend/worker_async'

module ThreeScale
  module Backend
    describe WorkerAsync, if: configuration.redis.async do
      let(:job_fetcher) { instance_double('JobFetcher') }

      describe '#work' do
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

      describe '#process_all' do
        subject { WorkerAsync.new(job_fetcher: job_fetcher) }

        let(:test_job_1) { "background job 1" }
        let(:test_job_2) { "background job 2" }
        let(:queue) { subject.instance_variable_get(:@jobs) }

        before do
          Logging::Worker.configure_logging(Worker, '/dev/null')
        end

        it "exits only after all jobs finished processing" do
          expect(subject).to receive(:perform).once.ordered.with(test_job_1).and_wrap_original { sleep 0.5 }
          queue << test_job_1
          queue.close

          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          Sync do |task|
            task.with_timeout(2) do
              subject.send :process_all
            end
          end

          # more than half a second passed before `#process_all` exited
          expect(start).to be < Process.clock_gettime(Process::CLOCK_MONOTONIC) - 0.5
        end

        it "doesn't stop on nil when queue is closed but not empty" do
          expect(subject).to receive(:perform).once.ordered.with(test_job_1)
          expect(subject).to receive(:perform).once.ordered.with(test_job_2)
          expect(Worker.logger).to receive(:error).with("Worker received a nil job from queue.")

          queue << test_job_1 << nil << test_job_2
          queue.close

          Sync do |task|
            task.with_timeout(2) do
              subject.send :process_all
            end
          end
        end

        it "doesn't stop on nil when queue is empty but not closed" do
          expect(subject).to receive(:perform).once.ordered.with(test_job_1)
          expect(Worker.logger).to receive(:error).with("Worker received a nil job from queue.")

          queue << test_job_1 << nil

          expect { Sync { |task| task.with_timeout(0.5) { subject.send :process_all } } }.
            to raise_error(Async::TimeoutError)

          expect(queue).to be_empty
        end
      end

      describe '#clear_queue' do
        subject do
          WorkerAsync.new
        end

        let(:test_job) { instance_double('BackgroundJob') }
        let(:n_reports) { 10 }
        let(:queue) { SizedQueue.new(10).tap { |q| n_reports.times { q.push test_job } } }

        before do
          subject.instance_variable_set(:@jobs, queue)
        end

        it 'clears the queue'do
          expect(subject).to receive(:perform).exactly(n_reports).times.with(test_job)
          queue.close

          subject.send(:clear_queue)
        end

        # this is not an expected real usage scenario but we test it anyway
        it 'clears the queue also when new jobs are added during the execution' do
          n_new_reports = 5
          expect(subject).to receive(:perform).exactly(n_reports + n_new_reports).times.with(test_job)

          # The task will process all jobs in the queue and wait forever until the queue is closed
          task = Async { subject.send(:clear_queue) }
          Sync do
            barrier = Async::Barrier.new
            n_new_reports.times { barrier.async { queue.push test_job } }
            barrier.wait # We don't want to close the queue while there are still tasks pushing jobs to it
          end
          queue.close # Unlock the task

          # Interrupt the test if the task is locked for more than 10 seconds
          # We assume something went wrong
          t_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          while task.running?
            if Process.clock_gettime(Process::CLOCK_MONOTONIC) - t_start > 10
              task.stop
              raise 'The worker is taking too much to process the jobs'
            end

            sleep(0.1)
          end

          task.wait
        end
      end
    end
  end
end
