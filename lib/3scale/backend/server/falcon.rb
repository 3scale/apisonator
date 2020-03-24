module ThreeScale
  module Backend
    module Server
      class Falcon
        extend ThreeScale::Backend::Server::Utils

        def self.start(global_options, options, args)
          # Falcon does not support:
          # - options[:daemonize]
          # - options[:logfile]
          # - options[:errorfile]
          # - options[:pidfile]

          manifest = global_options[:manifest]
          return unless manifest

          argv = ['falcon']
          argv_add argv, true, '--bind', 'http://0.0.0.0'
          argv_add argv, options[:port], '--port', options[:port]

          # Starts the prometheus server if needed. Just once even when spanning
          # multiple workers.
          argv_add argv, true, '--preload', 'lib/3scale/prometheus_server.rb'

          server_model = manifest[:server_model]
          argv_add argv, true, '--count', server_model[:workers].to_s
        end

        def self.restart(global_options, options, args)
          argv = ['falcon', 'supervisor']
          argv_add argv, true, 'restart'
        end

        def self.stop(global_options, options, args)
          STDERR.puts 'Not implemented'
        end

        def self.status(global_options, options, args)
          STDERR.puts 'Not implemented'
        end

        def self.stats(global_options, options, args)
          STDERR.puts 'Not implemented'
        end

        def self.help(global_options, options, args)
          system('falcon --help')
        end
      end
    end
  end
end
