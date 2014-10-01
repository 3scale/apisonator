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
            name      = sanitize_name(name)
            metric_id = metric_id(name)

            raise MetricInvalid.new(name)            unless metric_id
            raise UsageValueInvalid.new(name, value) unless sane_value?(value)

            usage.update(metric_id => value)
          end
        end

        def process_ancestors(usage)
          usage.keys.inject(usage.dup) do |memo, id|
            ancestor_id(id).each do |ancestor_id|

              val = ThreeScale::Backend::Aggregator::get_value_of_set_if_exists(memo[id])
              if val.nil?
                memo[ancestor_id] ||= 0
                # need to do the to_i here because the value can be a string if the ancestor is passed
                # explictly on the usage. Can't do on parse_usage coz value might not bea Fixnum but at
                # '#'Fixnum
                memo[ancestor_id] = memo[ancestor_id].to_i
                memo[ancestor_id] += memo[id].to_i
              else
                memo[ancestor_id] = memo[id]
              end
            end

            memo
          end
        end

        # FIXME: as of right now the maximum depth of metrics/methods is 1, therefore let's skip the extra query
        # by using the ancestor_id method instead
        def ancestors_ids(id)
          results = []
          while id_of_parent = parent_id(id)
            results << id_of_parent
            id = id_of_parent
          end

          results
        end

        def ancestor_id(id)
          [parent_id(id)].compact
        end

        def parent_id(id)
          @parent_ids[id] ||= load_ancestor_id(id)
        end

        def load_ancestor_id(id)
          Memoizer.memoize_block(Memoizer.build_key(self,
                                        :load_ancestor_id, @service_id, id)) do
            storage.get(encode_key("metric/service_id:#{@service_id}/id:#{id}/parent_id"))
          end
        end

        def metric_id(name)
          @metric_ids[name] ||= load_metric_id(name)
        end

        def load_metric_id(name)
          Memoizer.memoize_block(Memoizer.build_key(self,
                                        :load_metric_id, @service_id, name)) do
            storage.get(encode_key("metric/service_id:#{@service_id}/name:#{name}/id"))
          end
        end

        def sanitize_name(name)
          name.strip
        end

        ## accepts postive integers or positive integers preffixed with # (for sets)
        def sane_value?(value)
          value.is_a?(Numeric) || value.to_s =~ /\A\s*#?\d+\s*\Z/
        end
      end
    end
  end
end
