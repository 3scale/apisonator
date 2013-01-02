require '3scale/backend/metric/collection'

module ThreeScale
  module Backend
    class Metric < ThreeScale::Core::Metric
      # Load all metrics associated to the given service id.
      #def self.load_all(service_id)
      #  Collection.new(service_id)
      #end

      ## memoize loading the usage limits of the plan
      def self.load_all(service_id)
        key = "Metric.load_all-#{service_id}"
        
        if !Memoizer.memoized?(key)
          Memoizer.memoize(key, Collection.new(service_id))
        else
          Memoizer.get(key)
        end
      end
      
      def self.load_all_names(service_id, metric_ids)
        key = "Metric.load_all_names-#{service_id}-#{metric_ids}"

        if !Memoizer.memoized?(key)
          Memoizer.memoize(key, super(service_id, metric_ids))
        else
          Memoizer.get(key)
        end
      end
      
    end
  end
end
