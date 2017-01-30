module ThreeScale
  module Backend
    class FailedJobsScheduler
      TTL_RESCHEDULE_S = 30
      private_constant :TTL_RESCHEDULE_S

      # We need to limit the amount of failed jobs that we reschedule each
      # time. Even a small Redis downtime can cause lots of failed jobs and we
      # want to avoid spending more time than the TTL defined above. Otherwise,
      # several reschedule jobs might try to run at the same time.
      MAX_JOBS_TO_RESCHEDULE = 20_000
      private_constant :MAX_JOBS_TO_RESCHEDULE

      class << self
        include Backend::Logging

        def reschedule_failed_jobs
          # There might be several callers trying to requeue failed jobs at the
          # same time. We need to use a lock to avoid rescheduling the same
          # failed job more than once.
          key = dist_lock.lock

          count = rescheduled = 0

          if key
            count = number_of_jobs_to_reschedule
            count.times do
              reschedule_ok = requeue_oldest_failed_job
              rescheduled += 1 if reschedule_ok
              remove_oldest_failed_job
            end

            dist_lock.unlock if key == dist_lock.current_lock_key
          end

          { rescheduled: rescheduled,
            failed_while_rescheduling: count - rescheduled,
            failed_current: failed_queue.count }
        end

        private

        def dist_lock
          @dist_lock ||= DistributedLock.new(
              self.name, TTL_RESCHEDULE_S, Storage.instance)
        end

        def failed_queue
          @failed_jobs_queue ||= Resque::Failure
        end

        def number_of_jobs_to_reschedule
          [failed_queue.count, MAX_JOBS_TO_RESCHEDULE].min
        end

        # Returns true when the job is successfully rescheduled. False
        # otherwise.
        def requeue_oldest_failed_job
          failed_queue.requeue(0)
          true
        rescue Resque::Helpers::DecodeException
          # This means we tried to dequeue a job with invalid encoding.
          # We just want to delete it from the queue.
          #
          # We know that Cubert is responsible for errors of this type.
          # For that reason, we do not need to notify Airbrake.
          false
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
          logger.notify(e)
          false
        end

        def remove_oldest_failed_job
          failed_queue.remove(0)
        end

      end
    end
  end
end
