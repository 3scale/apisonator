module ThreeScale
  module Backend
    module Transactor
      
      # Job for writing stats to cassandra 
      class StatsJob
        extend Configurable
        include Aggregator::StatsBatcher

        @queue = :main

        def self.perform(old_bucket)
    
          return unless cassandra_enabled?
      
          bucket_to_move = get_oldest_bucket_blocking(old_bucket)
          
          return if bucket_to_move.nil?
      
          keys_that_changed = storage.smembers(changed_keys_bucket_key(bucket))
          
          return if keys_that_changed.nil? || keys_that_changed.empty?
          
          values = storage.mget(*keys_that_changed)
          
          str = "BEGIN BATCH "
          keys_that_changed.each_with_index do |key, i|
            
            
            
          end
          
          
          
        end

      end
    end
  end
end
