require 'ostruct'

module ThreeScale
  module Backend
    class Configuration < OpenStruct
      def initialize(file)
        super()

        all_configs = YAML.load(File.read(file))
        config = all_configs[ThreeScale::Backend.environment]

        config && config.each do |key, value|
          send("#{key}=", value)
        end
      end
    end

    def self.configuration_file
      File.expand_path(File.dirname(__FILE__) + '/../../../config.yml')
    end

    def self.configuration
      @configuration ||= Configuration.new(configuration_file)
    end
  end
end
