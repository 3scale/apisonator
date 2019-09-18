module ThreeScale
  module Backend
    class Transaction
      # We accept transactions with a timestamp ts where ts:
      # now - REPORT_DEADLINE_PAST <= ts <= now + REPORT_DEADLINE_FUTURE
      REPORT_DEADLINE_PAST = 24*60*60
      private_constant :REPORT_DEADLINE_PAST

      REPORT_DEADLINE_FUTURE = 60*60
      private_constant :REPORT_DEADLINE_FUTURE

      # We can define an allowed range assuming Time.now = 0
      DEADLINE_RANGE = (-REPORT_DEADLINE_PAST..REPORT_DEADLINE_FUTURE).freeze
      private_constant :DEADLINE_RANGE

      ATTRIBUTES = [:service_id, :application_id, :timestamp,
                    :log, :usage, :response_code]
      private_constant :ATTRIBUTES

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
           (response_code.is_a?(Integer) && (100 ..999).cover?(response_code) )
          response_code.to_i
        else
          false
        end
      end

      # Validates if transaction timestamp is within accepted range
      #
      # @return [unspecified] if the timestamp is within the valid range.
      # @raise [TransactionTimestampTooOld] if the timestamp is too old
      # @raise [TransactionTimestampTooNew] if the timestamp is too new
      def ensure_on_time!
        time_diff_sec = timestamp.to_i - Time.now.to_i

        unless DEADLINE_RANGE.cover?(time_diff_sec)
          if time_diff_sec < 0
            fail(TransactionTimestampTooOld, REPORT_DEADLINE_PAST)
          else
            fail(TransactionTimestampTooNew, REPORT_DEADLINE_FUTURE)
          end
        end
      end
    end
  end
end
