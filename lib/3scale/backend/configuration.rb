require 'ostruct'

module ThreeScale
  module Backend
    class Configuration < OpenStruct
      # Add configuration section with the given fields.
      #
      # == Example
      #
      #   # Define section like this
      #   ThreeScale::Backend.configuration.add_section(:bacons, :type, :amount)
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
      def add_section(name, *fields)
        send("#{name}=", Struct.new(*fields).new)
      end

      # Load configuration from a file (in /etc)
      def load!
        paths = ['/etc/3scale_backend.conf', '~/.3scale_backend.conf']
        paths.each do |path|
          load path if File.readable?(File.expand_path(path))
        end
      end
    end

    class << self
      def configure
        yield configuration
      end

      def configuration
        @configuration ||= Configuration.new
      end

      def configuration=(cfg)
        @configuration = cfg
      end
    end
  end
end
