require '3scale/backend/storage_key_helpers'

module ThreeScale
  module Backend
    class Metrics
      include StorageKeyHelpers

      # Load metrics associated to the given service id.
      def self.load(service_id)
        new({}, service_id)
      end

      def initialize(metrics = {}, service_id = nil)
        @service_id = service_id
        @metric_ids = {}
        @parent_ids = {}

        metrics.each do |id, attributes|
          initialize_metric(id, attributes)
        end
      end

      # Save metrics into the storage.
      def save(service_id)
        @service_id = service_id

        @metric_ids.each do |name, id|
          storage.set(key_for(:metric, :id, {:service_id => service_id}, {:name => name}), id)
        end

        @parent_ids.each do |id, parent_id|
          storage.set(key_for(:metric, :parent_id, {:service_id => service_id}, {:id => id}),
                      parent_id)
        end
      end

      # Accepts usage as {'metric_name' => value, ...} and converts it into
      # {metric_id => value, ...}, evaluating also metric hierarchy.
      #
      # == Example
      #
      # Let's supose there is a metric called "hits" with id 1001 and it has one child
      # metric called "search_queries" with id 1002. Then:
      #
      #   metrics.process_usage('search_queries' => 42)
      #
      # will produce:
      #
      #   {1001 => 42, 1002 => 42}
      #
      def process_usage(raw_usage)
        usage = parse_usage(raw_usage)
        usage = process_ancestors(usage)
        usage
      end

      private

      def parse_usage(raw_usage)
        (raw_usage || {}).inject(NumericHash.new) do |usage, (name, value)|
          metric_id = metric_id(sanitize_name(name))

          raise MetricNotFound unless metric_id
          raise UsageValueInvalid unless sane_value?(value)

          usage.update(metric_id => value.to_i)
        end
      end

      def process_ancestors(usage)
        usage.keys.inject(usage.dup) do |memo, id|
          ancestors_ids(id).each do |ancestor_id|
            memo[ancestor_id] ||= 0
            memo[ancestor_id] += memo[id]
          end

          memo
        end
      end

      def ancestors_ids(id)
        results = []
        while id_of_parent = parent_id(id)
          results << id_of_parent
          id = id_of_parent
        end

        results
      end

      def parent_id(id)
        @parent_ids[id] ||= load_ancestor_id(id)
      end

      def load_ancestor_id(id)
        storage.get(key_for(:metric, :parent_id, {:service_id => @service_id}, {:id => id}))
      end

      def metric_id(name)
        @metric_ids[name] ||= load_metric_id(name)
      end

      def load_metric_id(name)
        storage.get(key_for(:metric, :id, {:service_id => @service_id}, {:name => name}))
      end

      def sanitize_name(name)
        name.downcase.strip
      end

      def sane_value?(value)
        value.is_a?(Numeric) || value.to_s =~ /\A\s*\d+\s*\Z/
      end

      def initialize_metric(id, attributes)
        id = id.to_s

        @metric_ids[attributes[:name]] = id

        (attributes[:children] || {}).each do |child_id, child_attributes|
          @parent_ids[child_id.to_s] = id
          initialize_metric(child_id, child_attributes)
        end
      end

      def storage
        ThreeScale::Backend.storage
      end
    end
  end
end
