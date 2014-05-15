require 'thin'

module ThreeScale
  module Backend
    module Server
      extend self

      def start(options)
        log = !options[:daemonize] || options[:log_file]
        configuration = ThreeScale::Backend.configuration

        server = ::Thin::Server.new(options[:host], options[:port]) do
          if configuration.hoptoad.api_key
            Airbrake.configure do |config|
              config.api_key = configuration.hoptoad.api_key
            end
            use Airbrake::Sinatra
          end
          use ThreeScale::Backend::Logger if log

          ThreeScale::Backend::Server.mount_internal_api self
          run ThreeScale::Backend::Listener.new
        end

        server.pid_file = pid_file(options[:port])
        server.log_file = options[:log_file] || "/dev/null"

        # Hack to set process name (so it looks nicer in a process list).
        def server.name
          "3scale_backend listening on #{host}:#{port}"
        end

        puts ">> Starting #{server.name}. Let's roll!"
        server.daemonize if options[:daemonize]
        server.start
      end

      def stop(options)
        ::Thin::Server.kill(pid_file(options[:port]))
      end

      def restart(options)
        ::Thin::Server.restart(pid_file(options[:port]))
      end

      def pid_file(port)
        if ENV['RACK_ENV'] == 'development'
          "/tmp/3scale_backend_#{port}.pid"
        else
          "/var/run/3scale/3scale_backend_#{port}.pid"
        end
      end

      def mount_internal_api(server)
        mount_services_api server
        mount_toplevel_api server
      end

      def mount_services_api(server)
        server.map '/internal/services' do
          use Rack::Auth::Basic do |username, password|
            ThreeScale::Backend::Server.check_password username, password
          end

          run ThreeScale::Backend::ServicesAPI.new
        end
      end

      def mount_toplevel_api(server)
        server.map '/internal' do
          run ThreeScale::Backend::InternalAPI.new
        end
      end

      def check_password(username, password)
        username == ThreeScale::Backend::Server.auth_username &&
          password == ThreeScale::Backend::Server.auth_password
      end

      def auth_username
        'user'
      end

      def auth_password
        'password'
      end

    end
  end
end
