module ThreeScale
  module Backend
    class Application < Core::Application
      module Sets
        include HasSet

        has_set :referrer_filters
        has_set :keys
      end

      include Sets

      def self.load!(service_id, application_id)
        load(service_id, application_id) or raise ApplicationNotFound, application_id
      end

      def usage_limits
        UsageLimit.load_all(service_id, plan_id)
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
