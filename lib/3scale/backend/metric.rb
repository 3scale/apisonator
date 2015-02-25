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

        def metric_names_key(service_id)
          encode_key("metrics/service_id:#{service_id}/metric_names")
        end
      end

      include KeyHelpers
      extend KeyHelpers

      include Storable

      attr_accessor :service_id, :id, :parent_id, :name
      attr_writer :children

      def save
        save_attributes
        save_to_list

        save_children

        self.class.clear_cache(service_id, id)

        Service.incr_version(service_id)
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

        def load_all_ids(service_id)
          storage.smembers(id_set_key(service_id)) || []
        end

        def load_name(service_id, id)
          storage.get(key(service_id, id, :name))
        end
        memoize :load_name

        def load_all_names(service_id, ids)
          Hash[ids.zip(storage.mget(*ids.map { |id| key(service_id, id, :name) }))]
        end
        memoize :load_all_names

        def save(attributes)
          metrics = new(attributes)
          metrics.save
          metrics
        end

        def delete(service_id, id)
          name = load_name(service_id, id)
          return false unless name and not name.empty?
          clear_cache(service_id, id)

          storage.srem(id_set_key(service_id), id)

          storage.del(key(service_id, id, :name))
          storage.del(key(service_id, id, :parent_id))
          storage.del(id_key(service_id, name))

          Service.incr_version(service_id)
          true
        end

        def clear_cache(service_id, id)
          metric_ids = load_all_ids(service_id)
          Memoizer.clear(Memoizer.build_keys_for_class(self,
                                        load_all: [service_id],
                                        load_all_names: [service_id, metric_ids],
                                        load_name: [service_id, id]))
        end
      end

      private

      def save_attributes
        storage.set(id_key(service_id, name), id)
        storage.set(key(service_id, id, :name), name)
        storage.set(key(service_id, id, :parent_id), parent_id) if parent_id
      end

      def save_to_list
        storage.sadd(id_set_key(service_id), id)
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
