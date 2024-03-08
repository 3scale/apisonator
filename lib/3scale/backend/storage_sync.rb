# used to provide a Redis client based on a configuration object
require 'uri'

module ThreeScale
  module Backend
    class StorageSync
      include Configurable

      class << self
        # Returns a shared instance of the storage. If there is no instance yet,
        # creates one first. If you want to always create a fresh instance, set
        # the +reset+ parameter to true.
        def instance(reset = false)
          if reset || @instance.nil?
            @instance = new(Storage::Helpers.config_with(configuration.redis,
                            options: get_options))
          else
            @instance
          end
        end

        def new(options)
          Redis.new options
        end

        private

        if ThreeScale::Backend.production?
          def get_options
            {}
          end
        else
          DEFAULT_SERVER = '127.0.0.1:6379'.freeze
          private_constant :DEFAULT_SERVER

          def get_options
            { default_url: DEFAULT_SERVER }
          end
        end
      end
    end
  end
end
