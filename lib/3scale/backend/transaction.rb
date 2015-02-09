module ThreeScale
  module Backend
    class Transaction
      ATTRIBUTES = [:service_id, :application_id, :user_id, :timestamp,
                    :log, :usage, :response_code]

      class_eval { attr_accessor *ATTRIBUTES }

      def initialize(params = {})
        ATTRIBUTES.each { |attr| send("#{attr}=", (params[attr] || params[attr.to_s])) }
      end

      def timestamp=(value = nil)
        if value.is_a?(Time)
          @timestamp = value
        else
          @timestamp = Time.parse_to_utc(value) || Time.now.getutc
        end
      end

      # This is needed for tests
      # TODO: Remove it
      def [](key)
        send(key)
      end
    end
  end
end
