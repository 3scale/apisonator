require 'rack'
require 'thin'

module ThreeScale
  module Backend
    class Server
      class Rack
        class << self
          def new(options)
            ::Rack::Server.new(options)
          end

          def stop(options)
            ::Thin::Server.kill(options[:pid])
          end

          def restart(options)
            ::Thin::Server.restart(options[:pid])
          end
        end
      end
    end
  end
end
