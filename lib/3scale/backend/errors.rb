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

    class AccessTokenInvalid < NotFound
      def initialize(id = nil)
        super %(token "#{id}" is invalid: expired or never defined)
      end
    end

    class AccessTokenAlreadyExists < Error
      def initialize(id = nil)
        super %(token "#{id}" already exists)
      end
    end

    class AccessTokenStorageError < Error
      def initialize(id = nil)
        super %(storage error when saving token "#{id}")
      end
    end

    class AccessTokenFormatInvalid < Invalid
      def initialize
        super 'token is either too big or has an invalid format'.freeze
      end
    end

    class AccessTokenInvalidTTL < Invalid
      def initialize
        super 'the specified TTL should be a positive integer'.freeze
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

    class RequiredParamsMissing < Invalid
      def initialize
        super 'missing required parameters'.freeze
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

    # new errors for the user limiting
    class UserNotDefined < Error
      def initialize(id)
        super %(application with id="#{id}" requires a user (user_id))
      end
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

    class UserRequiresRegistration < Error
      def initialize(service_id, user_id)
        super %(user with user_id="#{user_id}" requires registration to use service with id="#{service_id}")
      end
    end

    class ServiceCannotUseUserId < Error
      def initialize(service_id)
        super %(service with service_id="#{service_id}" does not have access to end user plans, user_id is not allowed)
      end
    end

    class ServiceLoadInconsistency < Error
      def initialize(service_id, other_service_id)
        super %(service.load_by_id with id="#{service_id}" loaded the service with id="#{other_service_id}")
      end
    end

    # FIXME: this has to be about the only service-related error without
    # a service id in the reported message.
    class ServiceRequiresDefaultUserPlan < Error
      def initialize
        super 'Services without the need for registered users require a default user plan'.freeze
      end
    end

    class ServiceIsDefaultService < Error
      def initialize(id = nil)
        super %(Service id="#{id}" is the default service, cannot be removed)
      end
    end

    class ServiceRequiresRegisteredUser < Error
      def initialize(id = nil)
        super %(Service id="#{id}" requires users to be registered beforehand)
      end
    end

    class UserRequiresUsername < Error
      def initialize
        super 'User requires username'.freeze
      end
    end

    class UserRequiresServiceId < Error
      def initialize
        super 'User requires a service ID'.freeze
      end
    end

    class UserRequiresValidService < Error
      def initialize
        super 'User requires a valid service, the service does not exist'.freeze
      end
    end

    class UserRequiresDefinedPlan < Error
      def initialize
        super 'User requires a defined plan'.freeze
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

    class ServiceTokenInvalid < Error
      def initialize(token)
        super %(service token "#{token}" is invalid)
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
  end
end
