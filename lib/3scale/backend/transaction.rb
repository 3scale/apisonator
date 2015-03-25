module ThreeScale
  module Backend
    class Transaction
      REPORT_DEADLINE = 24 * 3600
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


      def extract_response_code
        if (response_code.is_a?(String) && response_code =~ /\A\d{3}\z/) ||
           (response_code.is_a?(Fixnum) && (100 ..999).cover?(response_code) )
          response_code.to_i
        else
          false
        end
      end

      # Validates if transaction timestamp is within accepted range
      #
      # @return [true] if the timestamp is within the valid range.
      # @raise [ReportTimestampNotwithinrange] if the timestamp isn't within
      #   the valid range.
      def ensure_on_time!
        return true if (Time.now.getutc - timestamp) <= REPORT_DEADLINE
        fail ReportTimestampNotWithinRange, REPORT_DEADLINE
      end
    end
  end
end
