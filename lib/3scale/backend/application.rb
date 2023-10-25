module ThreeScale
  module Backend
    class Application
      include Storable

      # list of attributes to be fetched from storage
      ATTRIBUTES = [:state, :plan_id, :plan_name, :redirect_url].freeze
      private_constant :ATTRIBUTES

      attr_accessor :service_id, :id, *ATTRIBUTES
      attr_writer :metric_names

      def to_hash
        {
          service_id: service_id,
          id: id,
          state: state,
          plan_id: plan_id,
          plan_name: plan_name,
          redirect_url: redirect_url,
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
          (ATTRIBUTES + %i[service_id id metric_names].freeze).freeze
        end

        def load(service_id, id)
          return nil unless service_id and id
          values = storage.mget(storage_key(service_id, id, :state),
                                storage_key(service_id, id, :plan_id),
                                storage_key(service_id, id, :plan_name),
                                storage_key(service_id, id, :redirect_url))
          state, plan_id, plan_name, redirect_url = values

          # save a network call by just checking state here for existence
          return nil unless state

          new(service_id: service_id,
              id: id,
              state: state.to_sym,
              plan_id: plan_id,
              plan_name: plan_name,
              redirect_url: redirect_url)
        end
        memoize :load

        def load!(service_id, app_id)
          load(service_id, app_id) or raise ApplicationNotFound, app_id
        end
        memoize :load!

        def load_id_by_key(service_id, key)
          storage.get(id_by_key_storage_key(service_id, key))
        end
        memoize :load_id_by_key

        def save_id_by_key(service_id, key, id)
          raise ApplicationHasInconsistentData.new(id, key) if [service_id, id, key].any?(&:blank?)
          storage.set(id_by_key_storage_key(service_id, key), id).tap do
            Memoizer.memoize(Memoizer.build_key(self, :load_id_by_key, service_id, key), id)
          end
        end

        def delete_id_by_key(service_id, key)
          storage.del(id_by_key_storage_key(service_id, key)).tap do
            Memoizer.clear(Memoizer.build_key(self, :load_id_by_key, service_id, key))
          end
        end

        def load_by_id_or_user_key!(service_id, app_id, user_key)
          with_app_id_from_params service_id, app_id, user_key do |appid|
            load service_id, appid
          end
        end

        def extract_id!(service_id, app_id, user_key)
          with_app_id_from_params service_id, app_id, user_key do |appid|
            exists? service_id, appid and appid
          end
        end

        def exists?(service_id, id)
          storage.exists?(storage_key(service_id, id, :state))
        end
        memoize :exists?

        def delete(service_id, id)
          raise ApplicationNotFound, id unless exists?(service_id, id)
          delete_data service_id, id
          clear_cache service_id, id
        end

        def delete_data(service_id, id)
          storage.pipelined do |pipeline|
            delete_set(pipeline, service_id, id)
            delete_attributes(pipeline, service_id, id)
          end
        end

        def clear_cache(service_id, id)
          params = [service_id, id]
          keys = Memoizer.build_keys_for_class(self,
                    load: params,
                    load!: params,
                    exists?: params)
          Memoizer.clear keys
        end

        def applications_set_key(service_id)
          encode_key("service_id:#{service_id}/applications")
        end

        def save(attributes)
          application = new(attributes)
          application.save
          application
        end

        def storage_key(service_id, id, attribute)
          encode_key("application/service_id:#{service_id}/id:#{id}/#{attribute}")
        end

        private

        def id_by_key_storage_key(service_id, key)
          encode_key("application/service_id:#{service_id}/key:#{key}/id")
        end

        def delete_set(client, service_id, id)
          client.srem(applications_set_key(service_id), id)
        end

        def delete_attributes(client, service_id, id)
          client.del(
            ATTRIBUTES.map do |f|
              storage_key(service_id, id, f)
            end
          )
        end

        def with_app_id_from_params(service_id, app_id, user_key)
          if app_id
            raise AuthenticationError unless user_key.nil?
          elsif user_key
            app_id = load_id_by_key(service_id, user_key)
            raise UserKeyInvalid, user_key if app_id.nil?
          else
            raise ApplicationNotFound
          end

          yield app_id or raise ApplicationNotFound, app_id
        end
      end

      def save
        raise ApplicationHasNoState.new(id) if !state

        storage.pipelined do |pipeline|
          persist_attributes(pipeline)
          persist_set(pipeline)
        end

        self.class.clear_cache(service_id, id)

        Memoizer.memoize(Memoizer.build_key(self.class, :exists?, service_id, id), state)
      end

      def invalidate_cache(cmds, cache_key)
        # cache key cannot be just cache_key.
        # Command must be added to avoid collisions between different ops over same key
        cmds.each { |cmd| Memoizer.clear(Memoizer.build_key(self.class, cmd, cache_key)) }
      end

      def storage_key(attribute)
        self.class.storage_key(service_id, id, attribute)
      end

      def applications_set_key(service_id)
        self.class.applications_set_key(service_id)
      end

      def metric_names
        @metric_names ||= {}
      end

      def metric_name(metric_id)
        metric_names[metric_id] ||= Metric.load_name(service_id, metric_id)
      end

      # Sets @metric_names with the names of all the metrics for which there is
      # a usage limit that applies to the app, and returns it.
      def load_metric_names
        metric_ids = usage_limits.map(&:metric_id)
        @metric_names = Metric.load_all_names(service_id, metric_ids)
      end

      def usage_limits
        @usage_limits ||= UsageLimit.load_all(service_id, plan_id)
      end

      def load_all_usage_limits
        @usage_limits = UsageLimit.load_all(service_id, plan_id)
      end

      # Loads the usage limits affected by the metrics received, that is, the
      # limits that are defined for those metrics plus all their ancestors in
      # the metrics hierarchy.
      # Raises MetricInvalid when a metric does not exist.
      def load_usage_limits_affected_by(metric_names)
        metric_ids = metric_names.flat_map do |name|
          [name] + Metric.ascendants(service_id, name)
        end.uniq.map do |name|
          Metric.load_id(service_id, name) || raise(MetricInvalid.new(name))
        end

        # IDs are sorted to be able to use the memoizer
        @usage_limits = UsageLimit.load_for_affecting_metrics(service_id, plan_id, metric_ids.sort)
      end

      def active?
        state == :active
      end

      #
      # KEYS
      #

      def keys
        # We memoize with self.class to avoid caching the result for specific
        # instances as opposed to the combination of service_id and app_id.
        db_key = storage_key(:keys)
        key = Memoizer.build_key(self.class, :smembers, db_key)
        Memoizer.memoize_block(key) do
          storage.smembers(db_key)
        end
      end

      # Create new application key and add it to the list of keys of this app.
      # If value is nil, generates new random key, otherwise uses the given
      # value as the new key.
      def create_key(value = nil)
        db_key = storage_key(:keys)
        invalidate_cache([:smembers, :scard], db_key)
        value ||= SecureRandom.hex(16)
        storage.sadd(db_key, value)
        value
      end

      def delete_key(value)
        db_key = storage_key(:keys)
        invalidate_cache([:smembers, :scard, :sismember], db_key)
        storage.srem?(db_key, value)
      end

      def has_keys?
        db_key = storage_key(:keys)
        key = Memoizer.build_key(self.class, :scard, db_key)
        Memoizer.memoize_block(key) do
          storage.scard(db_key).to_i > 0
        end
      end

      def has_no_keys?
        !has_keys?
      end

      def has_key?(value)
        db_key = storage_key(:keys)
        key = Memoizer.build_key(self.class, :sismember, db_key, value)
        Memoizer.memoize_block(key) do
          storage.sismember(db_key, value.to_s)
        end
      end

      #
      # REFERRER FILTER
      #

      def referrer_filters
        db_key = storage_key(:referrer_filters)
        key = Memoizer.build_key(self.class, :smembers, db_key)
        Memoizer.memoize_block(key) do
          storage.smembers(db_key)
        end
      end

      def create_referrer_filter(value)
        raise ReferrerFilterInvalid, "referrer filter can't be blank" if value.blank?
        db_key = storage_key(:referrer_filters)
        invalidate_cache([:smembers, :scard], db_key)
        storage.sadd(db_key, value)
        value
      end

      def delete_referrer_filter(value)
        db_key = storage_key(:referrer_filters)
        invalidate_cache([:smembers, :scard], db_key)
        storage.srem(db_key, value)
      end

      def has_referrer_filters?
        db_key = storage_key(:referrer_filters)
        key = Memoizer.build_key(self.class, :scard, db_key)
        Memoizer.memoize_block(key) do
          storage.scard(db_key).to_i > 0
        end
      end

      private

      def persist_attributes(client)
        client.set(storage_key(:state), state.to_s) if state
        client.set(storage_key(:plan_id), plan_id) if plan_id
        client.set(storage_key(:plan_name), plan_name) if plan_name
        client.set(storage_key(:redirect_url), redirect_url) if redirect_url
      end

      def persist_set(client)
        client.sadd(applications_set_key(service_id), id)
      end
    end
  end
end
