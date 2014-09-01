require_relative 'stats_info'

module ThreeScale
  module Backend
    module Aggregator
      module StatsBatcher

        def schedule_one_stats_job(bucket = "inf")
          Resque.enqueue(StatsJob, bucket, Time.now.getutc.to_f)
        end
      end
    end
  end
end
