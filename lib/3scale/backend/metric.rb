module ThreeScale
  module Backend
    module CoreMetric
      def self.included(base)
        base.include InstanceMethods, KeyHelpers
        base.extend ClassMethods, KeyHelpers
      end

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

      module InstanceMethods
        attr_writer :children

        def save
          storage.set(id_key(service_id, name), id)
          storage.set(key(service_id, id, :name), name)
          storage.set(key(service_id, id, :parent_id), parent_id) if parent_id

          storage.sadd(id_set_key(service_id), id)

          save_children
          Service.incr_version(service_id)
        end

        def children
          @children ||= []
        end

        private

        def save_children
          children.each do |child|
            child.service_id = service_id
            child.parent_id = id
            child.save
          end
        end
      end

      module ClassMethods
        def load_all_ids(service_id)
          storage.smembers(id_set_key(service_id)) || []
        end

        def load(service_id, id)
          name, parent_id = storage.mget(key(service_id, id, :name),
                                         key(service_id, id, :parent_id))

          name && new(id: id.to_s,
                      service_id: service_id.to_s,
                      name: name,
                      parent_id: parent_id)
        end

        def load_all_names(service_id, ids)
          Hash[ids.zip(storage.mget(*ids.map { |id| key(service_id, id, :name) }))]
        end

        def load_name(service_id, id)
          storage.get(key(service_id, id, :name))
        end

        def load_id(service_id, name)
          storage.get(id_key(service_id, name))
        end

        def save(attributes)
          metrics = new(attributes)
          metrics.save
          metrics
        end

        def delete(service_id, id)
          name = load_name(service_id, id)

          storage.srem(id_set_key(service_id), id)

          storage.del(key(service_id, id, :name))
          storage.del(key(service_id, id, :parent_id))
          storage.del(id_key(service_id, name))

          Service.incr_version(service_id)
        end
      end
    end

    class Metric
      include Memoizer::Decorator
      include Core::Storable
      include CoreMetric

      attr_accessor :service_id, :id, :parent_id, :name

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

# this is required by our code, but it is nested inside class Metric
# require'ing it here ensures we always reopen the class instead of
# defining it.
require '3scale/backend/metric/collection'
