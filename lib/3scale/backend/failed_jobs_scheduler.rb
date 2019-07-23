require '3scale/backend/logging'

module ThreeScale
  module Backend
    class FailedJobsScheduler
      TTL_RESCHEDULE_S = 30
      private_constant :TTL_RESCHEDULE_S

      # We are going to reschedule a job only if the remaining time for the TTL
      # is at least SAFE_MARGIN_S. This is to minimize the chance of having 2
      # jobs running at the same time.
      SAFE_MARGIN_S = 0.25*TTL_RESCHEDULE_S
      private_constant :SAFE_MARGIN_S

      # We need to limit the amount of failed jobs that we reschedule each
      # time. Even a small Redis downtime can cause lots of failed jobs and we
      # want to avoid spending more time than the TTL defined above. Otherwise,
      # several reschedule jobs might try to run at the same time.
      MAX_JOBS_TO_RESCHEDULE = 20_000
      private_constant :MAX_JOBS_TO_RESCHEDULE

      PATTERN_INTEGER_JOB_ERROR = /undefined method `\[\]=' for .*:Integer*/.freeze
      private_constant :PATTERN_INTEGER_JOB_ERROR

      NO_JOBS_IN_QUEUE_ERROR = "undefined method `[]=' for nil:NilClass".freeze
      private_constant :NO_JOBS_IN_QUEUE_ERROR

      class << self
        include Backend::Logging

        def reschedule_failed_jobs
          # There might be several callers trying to requeue failed jobs at the
          # same time. We need to use a lock to avoid rescheduling the same
          # failed job more than once.
          key = dist_lock.lock

          ttl_expiration_time = Time.now + TTL_RESCHEDULE_S
          rescheduled = failed_while_rescheduling = 0

          if key
            number_of_jobs_to_reschedule.times do
              break unless time_for_another_reschedule?(ttl_expiration_time)

              requeue_result = requeue_oldest_failed_job

              if requeue_result[:rescheduled?]
                rescheduled += 1
              else
                failed_while_rescheduling += 1
              end

              # :ok_to_remove? is false only when the requeue() call fails
              # because there are no more jobs in the queue.
              requeue_result[:ok_to_remove?] ? remove_oldest_failed_job : break
            end

            dist_lock.unlock if key == dist_lock.current_lock_key
          end

          { rescheduled: rescheduled,
            failed_while_rescheduling: failed_while_rescheduling,
            failed_current: failed_queue.count }
        end

        private

        def dist_lock
          @dist_lock ||= DistributedLock.new(
              self.name, TTL_RESCHEDULE_S, Resque.redis)
        end

        def time_for_another_reschedule?(ttl_expiration_time)
          remaining = ttl_expiration_time - Time.now
          remaining >= SAFE_MARGIN_S
        end

        def failed_queue
          @failed_jobs_queue ||= Resque::Failure
        end

        def number_of_jobs_to_reschedule
          [failed_queue.count, MAX_JOBS_TO_RESCHEDULE].min
        end

        # Returns a hash with two symbol keys. ':rescheduled?' is a boolean
        # that indicates whether the job has been rescheduled successfully.
        # ':ok_to_remove?' is a boolean that indicates whether we should remove
        # the job from the queue. That is true when the job has been
        # rescheduled successfully and when we want to discard the job because
        # the error it raised.
        def requeue_oldest_failed_job
          failed_queue.requeue(0)
          { rescheduled?: true, ok_to_remove?: true }
        rescue Resque::Helpers::DecodeException => e
          # This means we tried to dequeue a job with invalid encoding.
          # We just want to delete it from the queue.
          logger.notify(e)
          { rescheduled?: false, ok_to_remove?: true }
        rescue Exception => e
          logger.notify(e)
          { rescheduled?: false, ok_to_remove?: ok_to_remove?(e.message)}
        end

        def ok_to_remove?(error_msg)
          # The dist lock we use does not guarantee mutual exclusion in all
          # cases. This can result in a 'NoMethodError' if requeue is
          # called with an index that is no longer valid.
          # The error msg raised in this case is the one defined in
          # NO_JOBS_IN_QUEUE_ERROR. We do not want to remove the job in this
          # case because the one we wanted to remove no longer exists.
          #
          # There are other cases that can result in a 'NoMethodError'.
          # The format that Resque expects for a job is a hash with fields
          # like payload, args, failed_at, timestamp, etc. However,
          # we have seen Fixnums enqueued. The root cause of that is not
          # clear, but it is a problem. A Fixnum does not raise a
          # DecodeException, but when Resque receives that 'job', it
          # raises a 'NoMethodError' because it tries to call [] (remember
          # that it expects a hash) on that Fixnum.
          # The error msg raised in this case matches the pattern
          # PATTERN_INTEGER_JOB_ERROR.
          # We need to make sure that we remove 'jobs' like this from the
          # queue, otherwise, they'll be retried forever.

          if PATTERN_INTEGER_JOB_ERROR =~ error_msg
            true
          elsif NO_JOBS_IN_QUEUE_ERROR == error_msg
            false
          else # Unknown error. Remove the job to avoid retrying it forever.
            true
          end
        end

        def remove_oldest_failed_job
          failed_queue.remove(0)
        end

      end
    end
  end
end
