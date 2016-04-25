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

          def requeue(_index)
            # Resque would enqueue a new job with the info stored in the object
            # at _index, but we do not need to do anything.
          end

          private

          attr_reader :failed_jobs
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

      describe '#reschedule failed jobs' do
        context 'when the lock cannot be acquired' do
          let(:failed_jobs) { %w(job1 job2) }
          let(:dist_lock) { double('dist_lock', lock: false) }

          before do
            failed_jobs.each { |job| subject.failed_queue.enqueue(job) }
            allow(subject).to receive(:dist_lock).and_return(dist_lock)
          end

          it 'returns a hash with the number of failed jobs unchanged and rescheduled = 0' do
            expect(subject.reschedule_failed_jobs)
                .to eq({ failed_current: failed_jobs.size, rescheduled: 0 })
          end
        end

        context 'when the lock can be acquired' do
          context 'and the failed jobs queue is empty' do
            it 'returns a hash with failed_current = 0 and rescheduled = 0' do
              expect(subject.reschedule_failed_jobs)
                  .to eq({ failed_current: 0, rescheduled: 0 })
            end
          end

          context 'and there are failed jobs in the queue' do
            let(:failed_jobs) { %w(job1 job2) }

            before do
              failed_jobs.each { |job| subject.failed_queue.enqueue(job) }
            end

            it 're-queues all the failed jobs' do
              expect(subject.failed_queue)
                  .to receive(:requeue)
                  .exactly(failed_jobs.size).times

              subject.reschedule_failed_jobs
            end

            it 'deletes the re-enqueued jobs from the queue of failed jobs' do
              subject.reschedule_failed_jobs
              expect(subject.failed_queue.count).to be_zero
            end

            it 'returns a hash with failed_current = 0 and rescheduled = number of failed before' do
              expect(subject.reschedule_failed_jobs)
                  .to eq({ failed_current: 0, rescheduled: failed_jobs.size })
            end
          end
        end
      end
    end
  end
end
