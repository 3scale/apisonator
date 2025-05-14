module ThreeScale
  module Backend
    module Server
      class Falcon
        extend ThreeScale::Backend::Server::Utils

        CONFIG = 'falcon.rb'

        def self.start(global_options, options, args)
          # Falcon does not support:
          # - options[:daemonize]
          # - options[:logfile]
          # - options[:errorfile]
          # - options[:pidfile]

          manifest = global_options[:manifest]
          return unless manifest

          ENV["PORT"] = options[:port] if options[:port]

          argv = ['falcon', 'host']
          argv_add argv, true, CONFIG
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
