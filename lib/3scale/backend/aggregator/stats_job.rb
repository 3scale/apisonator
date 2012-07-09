module ThreeScale
  module Backend
    module Aggregator
      
      # Job for writing stats to cassandra 
      class StatsJob
        extend Configurable
        
        @queue = :main

        def self.perform(old_bucket)
    
          return unless cassandra_enabled?
      
          bucket_to_save = Aggregator.get_oldest_bucket_blocking(old_bucket)
          
          return if bucket_to_save.nil?

          ## it will save all the changed keys from the oldest time bucket. If it
          ## fails it will but the bucket back to the set to that it can be processed
          ## by another StatsJob
          Aggregator.save_to_cassandra(bucket_to_save)
          
        end

      end
    end
  end
end
