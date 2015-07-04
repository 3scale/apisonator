require 'thin'

module ThreeScale
  module Backend
    class Server
      class << self
        attr_reader :log

        def start(options)
          @log = !options[:daemonize] || options[:log_file]

          options[:tag] = "3scale_backend #{ThreeScale::Backend::VERSION}"

          options[:rackup] = ThreeScale::Backend.root_dir + '/config.ru'
          rackup_code = File.read(options[:rackup])

          app = eval("Rack::Builder.new {( #{rackup_code}\n )}.to_app", TOPLEVEL_BINDING, options[:rackup])

          server = ::Thin::Server.new(options[:host], options[:port], options, app)

          server.pid_file = pid_file(options[:port])
          server.log_file = options[:log_file] || "/dev/null"

          puts ">> Starting #{options[:tag]}. Let's roll!"
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
          if ThreeScale::Backend.development?
            "/tmp/3scale_backend_#{port}.pid"
          else
            "/var/run/3scale/3scale_backend_#{port}.pid"
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
end
