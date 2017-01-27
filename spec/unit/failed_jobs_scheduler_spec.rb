module ThreeScale
  module Backend
    describe FailedJobsScheduler do
      # To simplify these tests, I have defined a FakeFailedQueue class that
      # emulates the behaviour of the queue of failed jobs in Resque.
      # This should be easier than creating real jobs that fail with the proper
      # parameters set and all that.
      # The FailedJobScheduler class is monkey-patched to use an instance of
      # the FakeFailedQueue class.
      # Also, we do not test cases where failed jobs are added to the queue or
      # deleted from it in the middle of a test.

      before(:all) do
        class FailedJobsScheduler
          class << self
            alias_method :original_failed_queue, :failed_queue

            def failed_queue
              @failed_jobs_queue ||= FakeFailedQueue.new
            end
          end
        end

        class FakeFailedQueue
          attr_reader :failed_jobs

          def initialize
            @failed_jobs = []
          end

          def count
            failed_jobs.size
          end

          def remove(index)
            failed_jobs.delete_at(index)
          end

          def enqueue(elem)
            failed_jobs.push(elem)
          end

          def requeue(index)
            # Resque would enqueue a new job with the info stored in the object
            # at _index, but we do not need to do anything.

            # We need to simulate cases where Resque::Helpers::DecodeException
            # and other exceptions are raised. In order to do so, to simplify,
            # we will raise DecodeException if the string is 'invalid_encoding'
            # and Exception when it is 'exception'
            if failed_jobs[index] == 'invalid_encoding'
              raise Resque::Helpers::DecodeException
            elsif failed_jobs[index] == 'exception'
              raise Exception.new
            end
          end
        end
      end

      subject { FailedJobsScheduler }

      # We need to clean the failed jobs queue after each test
      after(:each) do
        subject.failed_queue.count.times { subject.failed_queue.remove(0) }
      end

      after(:all) do
        class FailedJobsScheduler
          @failed_jobs_queue = nil

          class << self
            alias_method :failed_queue, :original_failed_queue
          end
        end
      end

      shared_examples 'jobs that fail to be re-enqueued' do |jobs, reenqueue_fails, notify_error|
        before do
          jobs.each { |job| subject.failed_queue.enqueue(job) }
        end

        it 'tries to requeue all the jobs in the queue' do
          expect(subject.failed_queue)
              .to receive(:requeue).and_call_original
              .exactly(jobs.size).times

          subject.reschedule_failed_jobs
        end

        # This behavior might change in the future
        it 'removes all the jobs from the queue including the invalid ones' do
          subject.reschedule_failed_jobs
          expect(subject.failed_queue.count).to be_zero
        end

        it 'returns the correct number of rescheduled, failed and current jobs' do
          expect(subject.reschedule_failed_jobs)
              .to eq({ rescheduled: jobs.size - reenqueue_fails,
                       failed_while_rescheduling: reenqueue_fails,
                       failed_current: 0 })
        end

        if notify_error
          it 'notifies the error' do
            expect(subject.logger).to receive :notify
            subject.reschedule_failed_jobs
          end
        else
          it 'does not notify an error' do
            expect(subject.logger).not_to receive :notify
            subject.reschedule_failed_jobs
          end
        end
      end

      describe '.reschedule_failed_jobs' do
        context 'when the lock cannot be acquired' do
          let(:failed_jobs) { %w(job1 job2) }
          let(:dist_lock) { double('dist_lock', lock: false) }

          before do
            failed_jobs.each { |job| subject.failed_queue.enqueue(job) }
            allow(subject).to receive(:dist_lock).and_return(dist_lock)
          end

          it 'returns the correct number of rescheduled, failed and current jobs' do
            expect(subject.reschedule_failed_jobs)
                .to eq({ rescheduled: 0,
                         failed_while_rescheduling: 0,
                         failed_current: failed_jobs.size })
          end
        end

        context 'when the lock can be acquired' do
          context 'and the failed jobs queue is empty' do
            it 'returns the correct number of rescheduled, failed and current jobs' do
              expect(subject.reschedule_failed_jobs)
                  .to eq({ rescheduled: 0,
                           failed_while_rescheduling: 0,
                           failed_current: 0 })
            end
          end

          context 'and there are failed jobs in the queue' do
            let(:failed_jobs) { %w(job1 job2) }

            before do
              failed_jobs.each { |job| subject.failed_queue.enqueue(job) }
            end

            it 're-queues all the failed jobs' do
              expect(subject.failed_queue)
                  .to receive(:requeue).and_call_original
                  .exactly(failed_jobs.size).times

              subject.reschedule_failed_jobs
            end

            it 'deletes the re-enqueued jobs from the queue of failed jobs' do
              subject.reschedule_failed_jobs
              expect(subject.failed_queue.count).to be_zero
            end

            it 'returns the correct number of rescheduled, failed and current jobs' do
              expect(subject.reschedule_failed_jobs)
                  .to eq({ rescheduled: failed_jobs.size,
                           failed_while_rescheduling: 0,
                           failed_current: 0 })
            end
          end

          context 'when the number of failed jobs is higher than the defined max to reschedule' do
            let(:failed_jobs) { %w(job1 job2) }
            let(:max_to_reschedule) { 1 }

            before do
              failed_jobs.each { |job| subject.failed_queue.enqueue(job) }

              # To make the tests easier, set the max to a low number.
              stub_const('ThreeScale::Backend::FailedJobsScheduler::MAX_JOBS_TO_RESCHEDULE',
                         max_to_reschedule)
            end

            it 're-queues only the max defined instead of all the failed jobs' do
              expect(subject.failed_queue)
                  .to receive(:requeue).and_call_original
                  .exactly(max_to_reschedule).times

              subject.reschedule_failed_jobs
            end

            it 'deletes the re-enqueued jobs from the queue of failed_jobs' do
              subject.reschedule_failed_jobs

              expect(subject.failed_queue.failed_jobs)
                  .to eq failed_jobs[max_to_reschedule..-1]
            end

            it 'returns the correct number of rescheduled, failed and current jobs' do
              expect(subject.reschedule_failed_jobs)
                  .to eq({ rescheduled: max_to_reschedule,
                           failed_while_rescheduling: 0,
                           failed_current: failed_jobs.size - max_to_reschedule })
            end
          end

          context 'and an exception is raised when re-queuing a job' do
            context 'and it is because the job has invalid encoding (raises DecodeException)' do
              include_examples 'jobs that fail to be re-enqueued',
                               %w(job1 job2 invalid_encoding job3), 1, false
            end

            context 'and it is not because the job has invalid encoding' do
              include_examples 'jobs that fail to be re-enqueued',
                               %w(job1 job2 exception job3), 1, true
            end
          end
        end
      end
    end
  end
end
