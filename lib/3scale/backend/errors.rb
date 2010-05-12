module ThreeScale
  module Backend
    ERROR_MESSAGES = {
      'user.invalid_key'             => 'user_key is invalid',
      'user.inactive_contract'       => 'contract is not active',
      'user.exceeded_limits'         => 'usage limits are exceeded',
      'user.exceeded_credit'         => 'credit is exceeded',
      'provider.invalid_key'         => 'provider authentication key is invalid',
      'provider.invalid_metric'      => 'metric does not exist',
      'provider.invalid_usage_value' => 'usage value is invalid'}

    class Error < RuntimeError
    end

    class SingleError < Error
      attr_reader :code

      def initialize(code, message = nil)
        super(message || ERROR_MESSAGES[code])
        @code = code
      end

      def to_xml(options = {})
        xml = Builder::XmlMarkup.new
        xml.instruct! unless options[:skip_instruct]
        xml.errors do
          xml.error(message, :code => code)
        end

        xml.target!
      end
    end
    
    class UserKeyInvalid < SingleError
      def initialize
        super('user.invalid_key')
      end
    end

    class ContractNotActive < SingleError
      def initialize
        super('user.inactive_contract')
      end
    end

    # class LimitsExceeded < SingleError
    #   def initialize(message = nil)
    #     super('user.exceeded_limits', message)
    #   end
    # end

    # class CreditExceeded < SingleError
    #   def initialize
    #     super('user.exceeded_credit')
    #   end
    # end

    class ProviderKeyInvalid < SingleError
      def initialize
        super('provider.invalid_key')
      end
    end

    class MetricNotFound < SingleError
      def initialize
        super('provider.invalid_metric')
      end
    end

    class UsageValueInvalid < SingleError
      def initialize
        super('provider.invalid_usage_value')
      end
    end

    # This error can be raised in batch-processed transaction, where multiple transaction can
    # be invalid, but all have to be reported at the same time.
    class MultipleErrors < Error
      attr_reader :codes

      def initialize(codes)
        @codes = codes
      end

      def messages
        codes.map { |index, code| "#{index}: #{ERROR_MESSAGES[code]}" }
      end

      def message
        messages.join("\n")
      end

      def to_xml(options = {})
        xml = Builder::XmlMarkup.new
        xml.instruct! unless options[:skip_instruct]
        xml.errors do
          codes.each do |index, code|
            xml.error ERROR_MESSAGES[code], :code => code, :index => index
          end
        end

        xml.target!
      end
    end
  end
end
