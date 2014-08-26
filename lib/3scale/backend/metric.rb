require '3scale/backend/metric/collection'

module ThreeScale
  module Backend
    class Metric < ThreeScale::Core::Metric
      include Memoizer::Decorator

      def self.load_all(service_id)
        Collection.new(service_id)
      end
      memoize :load_all

      def self.load_all_names(service_id, metric_ids)
        super(service_id, metric_ids)
      end
      memoize :load_all_names

      def self.load_name(service_id, metric_id)
        super(service_id, metric_id)
      end
      memoize :load_name

    end
  end
end
