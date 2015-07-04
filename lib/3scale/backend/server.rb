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

          server = get_server(options[:server]).new options
          server.start do |srv|
            puts ">> Starting #{options[:tag]}. Let's roll!"
          end
        end

        def pid_file(port)
          if ThreeScale::Backend.development?
            "/tmp/3scale_backend_#{port}.pid"
          else
            "/var/run/3scale/3scale_backend_#{port}.pid"
          end
        end

        def method_missing(m, *args, &blk)
          options = args.first
          get_server(options[:server]).send(m.to_s.tr('-', '_'), options.merge(pid: pid_file(options[:Port])))
        end

        # the methods below are used by the Rack application for auth
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

        private

        def get_server(server_name)
          server_name ||= :puma
          server_name = server_name.to_s.tr('-', '_')
          require "3scale/backend/server/#{server_name}"
          class_name = server_name.split('_').map(&:capitalize).join
          const_get(class_name)
        rescue LoadError
          require '3scale/backend/server/rack'
          Rack
        end
      end

    end
  end
end
