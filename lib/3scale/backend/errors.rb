module ThreeScale
  module Backend
    class Error < RuntimeError
      def to_xml(options = {})
        xml = Builder::XmlMarkup.new
        xml.instruct! unless options[:skip_instruct]
        xml.error(message, :code => code)

        xml.target!
      end

      # Note: DON'T change this to http_status; Sinatra will pick it up and break!
      def http_code
        403
      end

      def code
        self.class.code
      end

      def self.code
        underscore(name[/[^:]*$/])
      end

      def self.underscore(string)
        string.gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
               gsub(/([a-z\d])([A-Z])/,'\1_\2').
               downcase
      end
    end

    class BadRequest < Error
      def initialize(msg = 'request contains syntax errors, should not be repeated without modification'.freeze)
        super msg
      end

      def http_code
        400
      end
    end

    class NotFound < Error
      def http_code
        404
      end
    end

    class Invalid < Error
      def http_code
        422
      end
    end

    class ApplicationKeyInvalid < Error
      def initialize(key)
        if key.blank?
          super 'application key is missing'.freeze
        else
          super %(application key "#{key}" is invalid)
        end
      end
    end

    class ApplicationHasInconsistentData < Error
      def initialize(id, user_key)
        super %(Application id="#{id}" with user_key="#{user_key}" has inconsistent data and could not be saved)
      end
    end

    class ApplicationNotFound < NotFound
      def initialize(id = nil)
        super %(application with id="#{id}" was not found)
      end
    end

    class ServiceNotActive < Error
      def initialize
        super 'service is not active'.freeze
      end
    end

    class ApplicationNotActive < Error
      def initialize
        super 'application is not active'.freeze
      end
    end

    class OauthNotEnabled < Error
      def initialize
        super 'oauth is not enabled'.freeze
      end
    end

    class RedirectURIInvalid < Error
      def initialize(uri)
        super %(redirect_uri "#{uri}" is invalid)
      end
    end

    class RedirectURLInvalid < Error
      def initialize(url)
        super %(redirect_url "#{url}" is invalid)
      end
    end

    class LimitsExceeded < Error
      def initialize
        super 'usage limits are exceeded'.freeze
      end
    end

    class ProviderKeyInvalid < Error
      def initialize(key)
        super %(provider key "#{key}" is invalid)
      end
    end

    class ServiceIdInvalid < Error
      def initialize(id)
        super %(service id "#{id}" is invalid)
      end
    end

    class MetricInvalid < NotFound
      def initialize(metric_name)
        super %(metric "#{metric_name}" is invalid)
      end
    end

    class ReferrerFilterInvalid < Invalid
    end

    class NotValidData < Invalid
      def initialize
        super 'all data must be valid UTF8'.freeze
      end
    end

    class ReferrerFiltersMissing < Error
      def initialize
        super 'referrer filters are missing'.freeze
      end
    end

    class ReferrerNotAllowed < Error
      def initialize(referrer)
        if referrer.blank?
          super 'referrer is missing'.freeze
        else
          super %(referrer "#{referrer}" is not allowed)
        end
      end
    end

    class UsageValueInvalid < Error
      def initialize(metric_name, value)
        if !value.is_a?(String) || value.blank?
          super %(usage value for metric "#{metric_name}" can not be empty)
        else
          super %(usage value "#{value}" for metric "#{metric_name}" is invalid)
        end
      end
    end

    class UnsupportedApiVersion < Error
    end

    class TransactionTimestampNotWithinRange < Error
    end

    class TransactionTimestampTooOld < TransactionTimestampNotWithinRange
      def initialize(max_seconds)
        super %(reporting transactions older than #{max_seconds} seconds is not allowed)
      end
    end

    class TransactionTimestampTooNew < TransactionTimestampNotWithinRange
      def initialize(max_seconds)
        super %(reporting transactions more than #{max_seconds} seconds in the future is not allowed)
      end
    end

    class ServiceLoadInconsistency < Error
      def initialize(service_id, other_service_id)
        super %(service.load_by_id with id="#{service_id}" loaded the service with id="#{other_service_id}")
      end
    end

    class ServiceIsDefaultService < Error
      def initialize(id = nil)
        super %(Service id="#{id}" is the default service, cannot be removed)
      end
    end

    class InvalidProviderKeys < Error
      def initialize
        super 'Provider keys are not valid, must be not nil and different'.freeze
      end
    end

    class ProviderKeyExists < Error
      def initialize(key)
        super %(Provider key="#{key}" already exists)
      end
    end

    class ProviderKeyNotFound < Error
      def initialize(key)
        super %(Provider key="#{key}" does not exist)
      end
    end

    class InvalidEventType < Error
      def initialize(type)
        super %(Event type "#{type}" is invalid")
      end
    end

    class ProviderKeyOrServiceTokenRequired < Error
      def initialize
        super 'Provider key or service token are required'.freeze
      end
    end

    class ServiceIdMissing < Invalid
      def initialize
        super 'Service ID is missing'.freeze
      end
    end

    # The name for this class stays as ServiceTokenInvalid even though the more
    # correct name would be ServiceTokenOrIdInvalid to avoid breaking users.
    class ServiceTokenInvalid < Error
      def initialize(token, service_id)
        super %(service token "#{token}" or service id "#{service_id}" is invalid)
      end
    end

    # This is raised in these 2 situations:
    #   1) The request does not contain a valid provider key nor a service ID.
    #   2) The request contains a valid provider key, but does not contain a
    #      service ID, and the provider does not have a default service
    #      associated.
    class ProviderKeyInvalidOrServiceMissing < Error
      def initialize(provider_key)
        super %(provider key "#{provider_key}" invalid and/or service ID missing)
      end
    end

    # Legacy API support

    class AuthenticationError < Error
      def initialize
        super 'either app_id or user_key is allowed, not both'.freeze
      end
    end

    class UserKeyInvalid < Error
      def initialize(key)
        super %(user key "#{key}" is invalid)
      end
    end

    # Bad Requests
    class ContentTypeInvalid < BadRequest
      def initialize(content_type)
        super %(invalid Content-Type: #{content_type})
      end
    end

    class TransactionsIsBlank < BadRequest
      def initialize
        super 'transactions parameter is blank'.freeze
      end
    end

    class TransactionsFormatInvalid < BadRequest
      def initialize
        super 'transactions format is invalid'.freeze
      end
    end

    class TransactionsHasNilTransaction < BadRequest
      def initialize
        super 'transactions has a nil transaction'.freeze
      end
    end

    class ApplicationHasNoState < BadRequest
      def initialize(id)
        super %(Application with id="#{id}" has no state )
      end
    end

    class EndUsersNoLongerSupported < BadRequest
      def initialize
        super 'End-users are no longer supported, do not specify the user_id parameter'.freeze
      end
    end
  end
end
