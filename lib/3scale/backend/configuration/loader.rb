require 'ostruct'

module ThreeScale
  module Backend
    module Configuration
      class Loader < OpenStruct
        # Add configuration section with the given fields.
        #
        # == Example
        #
        #   # Define section like this
        #   loader = Loader.new
        #   loader.add_section(:bacons, :type, :amount)
        #
        #   # Configure default values like this
        #   loader.bacons.type   = :chunky
        #   loader.bacons.amount = 'a lot'
        #
        #   # Load the configuration with
        #   loader.load!
        #
        #   # Use like this
        #   loader.bacons.type # :chunky
        #
        def add_section(name, *fields)
          send("#{name}=", Struct.new(*fields).new)
        end

        # Load configuration from a set of files
        def load!
          paths = ['/etc/3scale_backend.conf', '~/.3scale_backend.conf']
          paths.each do |path|
            load path if File.readable?(File.expand_path(path))
          end
        end
      end
    end
  end
end
