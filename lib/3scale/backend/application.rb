module ThreeScale
  module Backend
    class Application < Core::Application
      include HasSet

      has_set :domain_constraints
      has_set :keys

      def self.load!(service_id, application_id)
        load(service_id, application_id) or raise ApplicationNotFound, application_id
      end

      def usage_limits
        UsageLimit.load_all(service_id, plan_id)
      end

      # Creates new application key and adds it to the list of keys of this application.
      # If +value+ is nil, generates new random key, otherwise uses the given value as
      # the new key.
      def create_key_with_generation(value = nil)
        create_key_without_generation(value || SecureRandom.hex(16))
      end

      alias_method :create_key_without_generation, :create_key
      alias_method :create_key, :create_key_with_generation

      def active?
        state == :active
      end
    end
  end
end
