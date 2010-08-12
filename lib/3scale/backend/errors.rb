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
    
    class ApplicationNotFound < Error
      def initialize(id)
        super %Q(application with id="#{id}" was not found)
      end
    end

    class ApplicationNotActive < Error
      def initialize
        super %Q(application is not active)
      end
    end

    class LimitsExceeded < Error
      def initialize
        super %Q(usage limits are exceeded)
      end
    end

    class ProviderKeyInvalid < Error
      def initialize(key)
        super %Q(provider key "#{key}" is invalid)
      end
    end

    class MetricInvalid < Error
      def initialize(metric_name)
        super %Q(metric "#{metric_name}" is invalid)
      end
    end

    class UsageValueInvalid < Error
      def initialize(metric_name, value)
        if value.nil? || value =~ /^\s*$/
          super %Q(usage value for metric "#{metric_name}" can't be empty)
        else
          super %Q(usage value "#{value}" for metric "#{metric_name}" is invalid)
        end
      end
    end

    class UnsupportedApiVersion < Error
    end
  end
end
