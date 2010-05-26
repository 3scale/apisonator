module ThreeScale
  module Backend
    class Metric
      class Collection
        include Core::Storable
      
        def initialize(service_id)
          @service_id = service_id
          @metric_ids = {}
          @parent_ids = {}
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
          (raw_usage || {}).inject({}) do |usage, (name, value)|
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
          storage.get(encode_key("metric/service_id:#{@service_id}/id:#{id}/parent_id"))
        end

        def metric_id(name)
          @metric_ids[name] ||= load_metric_id(name)
        end

        def load_metric_id(name)
          storage.get(encode_key("metric/service_id:#{@service_id}/name:#{name}/id"))
        end

        def sanitize_name(name)
          name.downcase.strip
        end

        def sane_value?(value)
          value.is_a?(Numeric) || value.to_s =~ /\A\s*\d+\s*\Z/
        end
      end
    end
  end
end
