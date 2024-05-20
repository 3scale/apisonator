require 'set'

module ThreeScale
  module Backend
    class Metric
      module KeyHelpers
        def key(service_id, id, attribute)
          encode_key("metric/service_id:#{service_id}/id:#{id}/#{attribute}")
        end

        def id_key(service_id, name)
          encode_key("metric/service_id:#{service_id}/name:#{name}/id")
        end

        def id_set_key(service_id)
          encode_key("metrics/service_id:#{service_id}/ids")
        end
      end

      include KeyHelpers
      extend KeyHelpers

      include Storable

      attr_accessor :service_id, :id, :parent_id, :name
      attr_writer :children

      def save
        old_name = self.class.load_name(service_id, id)
        storage.pipelined do |pipeline|
          save_attributes(pipeline)
          save_to_list(pipeline)
          remove_reverse_mapping(service_id, old_name) if old_name != name
        end

        # can't include this in the pipeline since it is a potentially
        # large number of commands.
        save_children

        self.class.clear_cache(service_id, id, name)
      end

      def children
        @children ||= []
      end

      def to_hash
        {
          service_id: service_id,
          id: id,
          parent_id: parent_id,
          name: name
        }
      end

      def update(attributes)
        attributes.each do |attr, val|
          public_send("#{attr}=", val)
        end
        self
      end

      class << self
        include Memoizer::Decorator

        def attribute_names
          %i[service_id id parent_id name children].freeze
        end

        def load(service_id, id)
          name, parent_id = storage.mget(key(service_id, id, :name),
                                         key(service_id, id, :parent_id))

          name && new(id: id.to_s,
                      service_id: service_id.to_s,
                      name: name,
                      parent_id: parent_id)
        end

        def load_all(service_id)
          Collection.new(service_id)
        end
        memoize :load_all

        def load_id(service_id, name)
          storage.get(id_key(service_id, name))
        end
        memoize :load_id

        def load_all_ids(service_id)
          # smembers is guaranteed to return an array of strings, even if empty
          storage.smembers(id_set_key(service_id))
        end
        memoize :load_all_ids

        def load_name(service_id, id)
          storage.get(key(service_id, id, :name))
        end
        memoize :load_name

        def load_all_names(service_id, ids)
          if ids.nil? || ids.empty?
            {}
          else
            name_keys = ids.map { |id| key(service_id, id, :name) }
            Hash[ids.zip(storage.mget(name_keys))]
          end
        end
        memoize :load_all_names

        def load_parent_id(service_id, id)
          storage.get(key(service_id, id, :parent_id))
        end
        memoize :load_parent_id

        def save(attributes)
          metrics = new(attributes)
          metrics.save
          metrics
        end

        # Returns a hash where the keys can only be parent metric ids (as
        # Strings) and their values are arrays of children.
        #
        # The as_names optional parameter (default: true) returns metric names
        # instead of metric ids when true.
        def hierarchy(service_id, as_names = true)
          h_ids = hierarchy_ids(service_id)
          return h_ids unless as_names

          metric_ids = Set.new(h_ids.keys + h_ids.values.flatten)
          return {} if metric_ids.empty?

          res = {}
          metric_names = load_all_names(service_id, metric_ids)

          h_ids.each do |m_id, c_ids|
            m_name = metric_names[m_id]
            res[m_name] = c_ids.map do |c_id|
              metric_names[c_id]
            end
          end

          res
        end
        memoize :hierarchy

        def children(service_id, id)
          hierarchy(service_id, false)[id.to_s]
        end

        # Returns the "descendants" of a metric, that is, its children,
        # grandchildren, etc. in the metric hierarchy of the given service.
        # In other words, the "descendants" of a metric are its children plus
        # the descendants of each of them.
        def descendants(service_id, metric_name)
          metrics_hierarchy = hierarchy(service_id)
          children = metrics_hierarchy[metric_name] || []

          children.reduce(children) do |acc, child|
            acc + descendants(service_id, child)
          end
        end
        memoize :descendants

        # Returns the "ascendants" of a metric, that is, its parent,
        # grandparent, etc. The "ascendants" of a metric are its parent plus
        # the ascendants of the parent.
        def ascendants(service_id, metric_name)
          parents_of_metric = parents(service_id, [metric_name])

          parents_of_metric.reduce(parents_of_metric) do |acc, parent|
            acc + ascendants(service_id, parent)
          end
        end
        memoize :ascendants

        # Given an array of metrics, returns an array without duplicates that
        # includes the names of the metrics that are parent of at least one of
        # the given metrics.
        def parents(service_id, metric_names)
          parents = []

          metric_names.each do |name|
            parent_id = load_parent_id service_id, load_id(service_id, name)
            if parent_id
              parents << load_name(service_id, parent_id)
            end
          end

          parents.uniq
        end

        def delete(service_id, id)
          name = load_name(service_id, id)
          return false unless name and not name.empty?
          clear_cache(service_id, id, name)

          storage.pipelined do |pipeline|
            pipeline.srem(id_set_key(service_id), id)

            pipeline.del(key(service_id, id, :name),
                         key(service_id, id, :parent_id),
                         id_key(service_id, name))
          end

          true
        end

        def clear_cache(service_id, id, name)
          metric_ids = load_all_ids(service_id)
          Memoizer.clear(Memoizer.build_keys_for_class(self,
                                        load_all: [service_id],
                                        load_all_names: [service_id, metric_ids],
                                        load_name: [service_id, id],
                                        load_id: [service_id, name],
                                        load_all_ids: [service_id]))
        end

        private

        def hierarchy_ids(service_id)
          ids = load_all_ids(service_id)
          parent_ids_keys = ids.map { |id| key(service_id, id, :parent_id) }

          parent_ids = storage.pipelined do |pipeline|
            parent_ids_keys.each_slice(PIPELINED_SLICE_SIZE).map do |slice|
              pipeline.mget(slice)
            end
          end.flatten

          parent_child_rels = parent_ids.zip(ids)

          parent_child_rels.inject({}) do |acc, (parent_id, child_id)|
            if parent_id # nil if child_id has no parent
              acc[parent_id] ||= []
              acc[parent_id] << child_id
            end
            acc
          end
        end
      end

      private

      def remove_reverse_mapping(service_id, name)
        storage.del id_key(service_id, name)
      end

      def save_attributes(client)
        client.set(id_key(service_id, name), id)
        client.set(key(service_id, id, :name), name)
        client.set(key(service_id, id, :parent_id), parent_id) if parent_id
      end

      def save_to_list(client)
        client.sadd(id_set_key(service_id), id)
      end

      def save_children
        children.each do |child|
          child.service_id = service_id
          child.parent_id = id
          child.save
        end
      end

    end
  end
end

# this is required by our code, but it is nested inside class Metric
# require'ing it here ensures we always reopen the class instead of
# defining it.
require '3scale/backend/metric/collection'
