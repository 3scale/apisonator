require 'ostruct'

module ThreeScale
  module Backend
    class Configuration < OpenStruct
      # Add configuration section with the given fields.
      #
      # == Example
      #
      #   # Define section like this
      #   ThreeScale::Backend.configuration.register_section(:bacons, :type, :amount)
      #
      #   # Configure it like this
      #   ThreeScale::Backend.configure do |config|
      #     # other stuff here ...
      #
      #     config.bacons.type   = :chunky
      #     config.bacons.amount = 'a lot'
      #
      #     # more stuff here ...
      #   end
      #
      #   # Use like this
      #   ThreeScale::Backend.configuration.bacons.type # :chunky
      #
      def register_section(name, *fields)
        send("#{name}=", Struct.new(*fields).new)
      end
    end

    # Include this into any class to provide convenient access to the configuration.
    module Configurable
      def self.included(base)
        base.extend(self)
      end

      def configuration
        ThreeScale::Backend.configuration
      end
    end

    def self.configure
      yield configuration
    end

    def self.configuration
      @@configuration ||= Configuration.new
    end

    # Register default sections
    configuration.register_section(:aws, :access_key_id, :secret_access_key)
  end
end
