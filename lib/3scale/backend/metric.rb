module ThreeScale
  module Backend
    class Metric < Core::Metric
      autoload :Collection, '3scale/backend/metric/collection'

      # Load all metrics associated to the given service id.
      def self.load_all(service_id)
        Collection.new(service_id)
      end
    end
  end
end
