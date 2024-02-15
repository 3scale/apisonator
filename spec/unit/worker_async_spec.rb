require_relative '../spec_helper'
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

        describe 'when there are pending jobs in the memory queue' do
          subject do
            WorkerAsync.new
          end

          let(:test_job) { instance_double('BackgroundJob') }
          let(:n_reports) { 10 }
          let(:queue) { Queue.new.tap { |q| n_reports.times { q.push test_job } } }

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

            # The thread will process all jobs in the queue and wait forever until the queue is closed
            thread = Thread.new { Sync { subject.send(:clear_queue) } }
            Sync do
              barrier = Async::Barrier.new
              n_new_reports.times { barrier.async { queue.push test_job } }
              barrier.wait # We don't want to close the queue while there are still tasks pushing jobs to it
            end
            queue.close # Unlock the thread

            # Interrupt the test if the thread is locked for more than 10 seconds
            # We assume something went wrong
            t_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            while thread.alive?
              if Process.clock_gettime(Process::CLOCK_MONOTONIC) - t_start > 10
                thread.kill
                raise 'The worker is taking too much to process the jobs'
              end

              sleep(0.1)
            end

            thread.join
          end
        end
      end
    end
  end
end
