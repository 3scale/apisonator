require '3scale/backend/metric/collection'

module ThreeScale
  module Backend
    class Metric < ThreeScale::Core::Metric
      # Load all metrics associated to the given service id.
      def self.load_all(service_id)
        Collection.new(service_id)
      end
    end
  end
end
