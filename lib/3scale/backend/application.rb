module ThreeScale
  module Backend
    class Application < Core::Application
      module Sets
        include HasSet

        has_set :referrer_filters
        has_set :keys
      end

      include Sets

      def self.load!(service_id, app_id)
        load(service_id, app_id) or raise ApplicationNotFound, app_id
      end

      def self.load_by_id_or_user_key!(service_id, app_id, user_key)
        case
        when app_id && user_key
          raise AuthenticationError
        when app_id
          load!(service_id, app_id)
        when user_key
          app_id = load_id_by_key(service_id, user_key) or raise UserKeyInvalid, user_key
          load(service_id, app_id) or raise UserKeyInvalid, user_key
        else
          raise ApplicationNotFound
        end
      end

      def self.extract_id!(service_id, app_id, user_key)
        case
        when app_id && user_key
          raise AuthenticationError
        when app_id
          exists?(service_id, app_id) and app_id or raise ApplicationNotFound, app_id
        when user_key
          app_id = load_id_by_key(service_id, user_key) or raise UserKeyInvalid, user_key
          exists?(service_id, app_id) and app_id or raise UserKeyInvalid, user_key
        else
          raise ApplicationNotFound
        end
      end

      def usage_limits
        @usage_limits ||= UsageLimit.load_all(service_id, plan_id)
      end

      # Creates new application key and adds it to the list of keys of this application.
      # If +value+ is nil, generates new random key, otherwise uses the given value as
      # the new key.
      def create_key(value = nil)
        super(value || SecureRandom.hex(16))
      end

      def create_referrer_filter(value)
        raise ReferrerFilterInvalid, "referrer filter can't be blank" if value.blank?
        super
      end

      def active?
        state == :active
      end
    end
  end
end
