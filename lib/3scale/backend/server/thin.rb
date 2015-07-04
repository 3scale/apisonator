require 'thin'

module ThreeScale
  module Backend
    class Server
      class Thin
        class << self
          def new(options)
            rackup_code = File.read(options[:config])
            app = eval("Rack::Builder.new {( #{rackup_code}\n )}.to_app", TOPLEVEL_BINDING, options[:config])
            ::Thin::Server.new(options[:Host], options[:Port], options, app).tap do |srv|
              srv.log_file = options[:log_file] || '/dev/null'
              srv.pid_file = options[:pid]
              srv.daemonize if options[:daemonize]
            end
          end
        end
      end
    end
  end
end
