module ThreeScale
  module Backend
    class Metric
      class Collection
        include Storable

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
          return {} unless raw_usage
          usage = parse_usage(raw_usage)
          process_parents(usage)
        end

        private

        def parse_usage(raw_usage)
          raw_usage.inject({}) do |usage, (name, value)|
            name = name.strip
            raise UsageValueInvalid.new(name, value) unless sane_value?(value)
            usage.update(metric_id(name) => value)
          end
        end

        def process_parents(usage)
          usage.keys.inject(usage.dup) do |memo, id|
            p_id = parent_id(id)
            if p_id
              if Usage.is_set? memo[id]
                memo[p_id] = memo[id]
              else
                # need the to_i here instead of in parse_usage because the value
                # can be a string if the parent is passed explictly on the usage
                # since the value might not be a Fixnum but a '#'Fixnum
                # (also because memo[p_id] might be nil)
                memo[p_id] = memo[p_id].to_i
                memo[p_id] += memo[id].to_i
              end
            end

            memo
          end
        end

        def parent_id(id)
          @parent_ids[id] ||= Metric.load_parent_id(@service_id, id)
        end

        def metric_id(name)
          @metric_ids[name] ||= load_metric_id(name)
        end

        def load_metric_id(name)
          Memoizer.memoize_block(Memoizer.build_key(self,
                                        :load_metric_id, @service_id, name)) do
            storage.get(encode_key("metric/service_id:#{@service_id}/name:#{name}/id"))
          end || raise(MetricInvalid.new(name))
        end

        ## accepts postive integers or positive integers preffixed with # (for sets)
        def sane_value?(value)
          value.is_a?(Numeric) || value.to_s =~ /\A\s*#?\d+\s*\Z/
        end
      end
    end
  end
end
