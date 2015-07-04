require 'thin'

module ThreeScale
  module Backend
    class Server
      class << self
        attr_reader :log

        def start(options)
          @log = !options[:daemonize] || options[:log_file]

          options[:tag] = "3scale_backend #{ThreeScale::Backend::VERSION}"
          options[:pid] = pid_file(options[:Port])
          options[:config] = ThreeScale::Backend.root_dir + '/config.ru'

          server = Rack::Server.new(options)

          server.start do |srv|
            puts ">> Starting #{options[:tag]}. Let's roll!"
            srv.log_file = options[:log_file] || '/dev/null' if srv.respond_to? :log_file
          end
        end

        def stop(options)
          ::Thin::Server.kill(pid_file(options[:Port]))
        end

        def restart(options)
          ::Thin::Server.restart(pid_file(options[:Port]))
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
