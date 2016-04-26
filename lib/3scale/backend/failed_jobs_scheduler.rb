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
              count = rescheduled = Resque::Failure.count
              count.times { |i| Resque::Failure.requeue(i) }
            rescue NoMethodError
              # The dist lock we use does not guarantee mutual exclusion in all
              # cases. This can result in a 'NoMethodError' if requeue is
              # called with an index that is no longer valid.
              retry
            end

            count.times { Resque::Failure.remove(0) }
            dist_lock.unlock if key == dist_lock.current_lock_key
          end

          { failed_current: Resque::Failure.count, rescheduled: rescheduled }
        end

        private

        def dist_lock
          @dist_lock ||= DistributedLock.new(
              self.name, TTL_RESCHEDULE_S, Storage.instance)
        end
      end
    end
  end
end
