require 'optparse'

module ThreeScale
  module Backend
    module Runner
      extend self

      DEFAULT_OPTIONS = {
        Host:'0.0.0.0',
        Port: '3000',
      }
      COMMANDS = [:start, :stop, :restart, :restore_backup]

      def run
        myopts, serveropts = ARGV.join(' ').split(' -- ')
        command, options = parse!(myopts ? myopts.split : [])
        options[:argv] = serveropts ? serveropts.split : []
        send command, options
      end

      def start(options)
        Server.start(options)
      end

      def stop(options)
        Server.stop(options)
      end

      def restart(options)
        Server.restart(options)
      end

      def restore_backup(options)
        puts ">> Replaying write commands from backup."
        Storage.instance(true).restore_backup
        puts ">> Done."
      end

      private

      def parse!(argv)
        options = DEFAULT_OPTIONS

        parser = OptionParser.new do |parser|
          parser.banner = 'Usage: 3scale_backend [options] command'
          parser.separator ""
          parser.separator "Options:"

          parser.on('-a', '--address HOST', 'bind to HOST address (default: 0.0.0.0)') { |value| options[:Host] = value }
          parser.on('-p', '--port PORT',    'use PORT (default: 3000)')                { |value| options[:Port] = value.to_i }
          parser.on('-d', '--daemonize',    'run as daemon')                           { |value| options[:daemonize] = true }
          parser.on('-l', '--log FILE' ,    'log file')                                { |value| options[:log_file] = value }
          parser.on('-s', '--server SERVER','app server')                              { |value| options[:server] = value }
          parser.on('--', 'rest of arguments are passed to the server')

          parser.separator ""
          parser.separator "Commands: #{COMMANDS.join(', ')}"

          parser.parse! argv
        end

        command = argv.shift
        command &&= command.to_sym

        unless COMMANDS.include?(command)
          if command
            abort "Unknown command: #{command}. Use one of: #{COMMANDS.join(', ')}"
          else
            abort parser.to_s
          end
        end

        [command, options]
      end
    end
  end
end
