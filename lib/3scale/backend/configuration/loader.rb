require 'ostruct'

module ThreeScale
  module Backend
    module Configuration
      class Loader < OpenStruct
        Error = Class.new StandardError
        NoConfigFiles = Class.new Error

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
        #   # Load the configuration from an array of files
        #   loader.load!(files)
        #
        #   # Use like this
        #   loader.bacons.type # :chunky
        #
        def add_section(name, *fields)
          send("#{name}=", Struct.new(*fields).new)
        end

        # Load configuration from a set of files
        def load!(files)
          raise NoConfigFiles if !files || files.empty?
          files.each do |path|
            load path if File.readable?(File.expand_path(path))
          end
        end
      end
    end
  end
end
