module ThreeScale
  module Backend
    class Error < RuntimeError
      def to_xml(options = {})
        xml = Builder::XmlMarkup.new
        xml.instruct! unless options[:skip_instruct]
        xml.error(message, :code => code)

        xml.target!
      end

      def code
        self.class.code
      end

      def self.code
        underscore(name[/[^:]*$/])
      end

      # TODO: move this over to some utility module.
      def self.underscore(string)
        # Code stolen from ActiveSupport
        string.gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
               gsub(/([a-z\d])([A-Z])/,'\1_\2').
               downcase
      end
    end

    NotFound = Class.new(Error)
    Invalid  = Class.new(Error)

    class ApplicationKeyInvalid < Error
      def initialize(key)
        if key.blank?
          super %(application key is missing)
        else
          super %(application key "#{key}" is invalid)
        end
      end
    end

    class ApplicationNotFound < NotFound
      def initialize(id = nil)
        super %(application with id="#{id}" was not found)
      end
    end

    class ApplicationNotActive < Error
      def initialize
        super %(application is not active)
      end
    end

    class OauthNotEnabled < Error
      def initialize
        super %(oauth is not enabled)
      end
    end

    class RedirectUrlInvalid < Error
      def initialize(url)
        super %(redirect_url "#{url}" is invalid)
      end
    end

    class LimitsExceeded < Error
      def initialize
        super %(usage limits are exceeded)
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

    class MetricInvalid < Error
      def initialize(metric_name)
        super %(metric "#{metric_name}" is invalid)
      end
    end

    class ReferrerFilterInvalid < Invalid
    end

    class ReferrerFiltersMissing < Error
      def initialize
        super 'referrer filters are missing'
      end
    end

    class ReferrerNotAllowed < Error
      def initialize(referrer)
        if referrer.blank?
          super %(referrer is missing)
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

    # new errors for the user limiting
    class UserNotDefined < Error
      def initialize(id)
        super %(application with id="#{id}" requires a user (user_id))
      end
    end


    class UserRequiresRegistration < Error
      def initialize(service_id, user_id)
        super %(user with user_id="#{user_id}" requires registration to use service with id="#{service_id}")
      end
    end

    class ServiceLoadInconsistency < Error
      def initialize(service_id, other_service_id)
        super %(service.load_by_id with id="#{service}" loaded the service with id="#{other_service_id}")
      end
    end


    # Legacy API support

    class AuthenticationError < Error
      def initialize
        super %(either app_id or user_key is allowed, not both)
      end
    end

    class UserKeyInvalid < Error
      def initialize(key)
        super %(user key "#{key}" is invalid)
      end
    end
  end
end
