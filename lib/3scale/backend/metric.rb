require '3scale/backend/metric/collection'

module ThreeScale
  module Backend
    class Metric < ThreeScale::Core::Metric
      def self.load_all(service_id)
        key = "Metric.load_all-#{service_id}"
        Memoizer.memoize_block(key) do 
          Collection.new(service_id)
        end
      end
      
      def self.load_all_names(service_id, metric_ids)
        key = "Metric.load_all_names-#{service_id}-#{metric_ids}"
        Memoizer.memoize_block(key) do 
          super(service_id, metric_ids)
        end
      end
      
      def self.load_name(service_id, metric_id)
        key = "Metric.load_name-#{service_id}-#{metric_id}"
        Memoizer.memoize_block(key) do 
          super(service_id, metric_id)
        end
      end
    end
  end
end
