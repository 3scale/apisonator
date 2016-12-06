module ThreeScale
  module Backend
    class FailedJobsScheduler
      TTL_RESCHEDULE_S = 30
      private_constant :TTL_RESCHEDULE_S

      class << self

        def reschedule_failed_jobs
          # There might be several callers trying to requeue failed jobs at the
          # same time. We need to use a lock to avoid rescheduling the same
          # failed job more than once.
          key = dist_lock.lock

          rescheduled = 0

          if key
            begin
              count = rescheduled = failed_queue.count
              count.times { |i| failed_queue.requeue(i) }
            rescue Resque::Helpers::DecodeException
              # This means we tried to dequeue a job with invalid encoding.
              # We just want to delete it from the queue. Although this might
              # change in the future. Marking it as non-rescheduled is enough.
              rescheduled -= 1
            rescue Exception => e
              # The dist lock we use does not guarantee mutual exclusion in all
              # cases. This can result in a 'NoMethodError' if requeue is
              # called with an index that is no longer valid.
              #
              # There are other cases that can result in a 'NoMethodError'.
              # The format that Resque expects for a job is a hash with fields
              # like payload, args, failed_at, timestamp, etc. However,
              # we have seen Fixnums enqueued. The root cause of that is not
              # clear, but it is a problem. A Fixnum does not raise a
              # DecodeException, but when Resque receives that 'job', it
              # raises a 'NoMethodError' because it tries to call [] (remember
              # that it expects a hash) on that Fixnum.
              # We need to make sure that we remove 'jobs' like this from the
              # queue, otherwise, they'll be retried forever.
              #
              # TODO: investigate if we can treat differently the different
              # types of exceptions that we can find here.
              Airbrake.notify(e)
              rescheduled -= 1
            end

            count.times { failed_queue.remove(0) }
            dist_lock.unlock if key == dist_lock.current_lock_key
          end

          { failed_current: failed_queue.count, rescheduled: rescheduled }
        end

        private

        def dist_lock
          @dist_lock ||= DistributedLock.new(
              self.name, TTL_RESCHEDULE_S, Storage.instance)
        end

        def failed_queue
          @failed_jobs_queue ||= Resque::Failure
        end
      end
    end
  end
end
