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
        def process_usage(raw_usage, flat_usage = false)
          return {} unless raw_usage
          usage = parse_usage(raw_usage)
          flat_usage ? usage : process_parents(usage)
        end

        private

        def parse_usage(raw_usage)
          raw_usage.inject({}) do |usage, (name, value)|
            name = name.strip
            raise UsageValueInvalid.new(name, value) unless sane_value?(value)
            usage.update(metric_id(name) => value)
          end
        end

        # Propagates the usage to all the levels of the hierarchy.
        # For example, in this scenario:
        # m1 --child_of--> m2 --child_of--> m3
        # If there's a +1 in m1, this method will set the +1 in the other 2 as
        # well.
        def process_parents(usage)
          usage.inject(usage.dup) do |memo, (id, val)|
            is_set_op = Usage.is_set?(val)

            while (id = parent_id(id))
              if is_set_op
                memo[id] = val
              else
                # need the to_i here instead of in parse_usage because the value
                # can be a string if the parent is passed explicitly on the usage
                # since the value might not be a Fixnum but a '#'Fixnum
                # (also because memo[p_id] might be nil)
                memo[id] = memo[id].to_i
                memo[id] += val.to_i
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
          Metric.load_id(@service_id, name) || raise(MetricInvalid.new(name))
        end

        ## accepts postive integers or positive integers preffixed with # (for sets)
        def sane_value?(value)
          value.is_a?(Numeric) || value.to_s =~ /\A\s*#?\d+\s*\Z/
        end
      end
    end
  end
end
