module ThreeScale
  module Backend
    class FailedJobsScheduler
      class << self

        # There might be several workers trying to requeue failed jobs at the same
        # time. This can result in a 'NoMethodError' if one of them calls
        # Resque::Failure.requeue with an index that is no longer valid.
        def reschedule_failed_jobs
          begin
            count = Resque::Failure.count
            count.times { |i| Resque::Failure.requeue(i) }
          rescue NoMethodError
            retry
          end

          Resque::Failure.clear
          { failed_current: Resque::Failure.count, failed_before: count}
        end

      end
    end
  end
end
