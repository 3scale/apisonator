require 'optparse'
require 'thin'

module ThreeScale
  module Backend
    class Runner
      def self.run
        new.run
      end

      def initialize
        @options = {:host => '0.0.0.0', :port => 3000}
      end

      attr_reader :options
      attr_reader :command

      COMMANDS = [:start, :stop, :restart, :restore_backup, :archive]

      def run
        parse!(ARGV)

        if COMMANDS.include?(command)
          send(command)
        else
          if command
            abort "Unknown command: #{command}. Use one of: #{COMMANDS.join(', ')}"
          else
            abort @parser.to_s
          end
        end        
      end

      def start
        require '3scale/backend'

        log = !options[:daemonize] || options[:log_file]

        server = Thin::Server.new(options[:host], options[:port]) do
          use HoptoadNotifier::Rack if HoptoadNotifier.configuration
          use Rack::CommonLogger    if log
          use Rack::ContentLength
          use Rack::RestApiVersioning, :default_version => '1.1'
          
          run ThreeScale::Backend::Router.new
        end

        server.pid_file = pid_file
        server.log_file = options[:log_file] || "/dev/null"

        # Hack to set the process name.
        def server.name
          "3scale_backend listening on #{host}:#{port}"
        end
 
        puts ">> Starting #{server.name}. Let's roll!"

        server.daemonize if options[:daemonize]
        server.start
      end

      def stop
        Thin::Server.kill(pid_file)
      end

      def restart
        Thin::Server.restart(pid_file)
      end

      def restore_backup
        require '3scale/backend'

        puts ">> Replaying write commands from backup."
        ThreeScale::Backend::Storage.instance(true).restore_backup
        puts ">> Done."
      end

      def archive
        require '3scale/backend'
        ThreeScale::Backend::Archiver.store(:tag => `hostname`.strip)
        ThreeScale::Backend::Archiver.cleanup
      end
      
      def pid_file
        "/var/run/3scale/3scale_backend_#{options[:port]}.pid"
      end

      private

      def parse!(argv)
        @parser = OptionParser.new do |parser|
          parser.banner = 'Usage: 3scale_backend [options] command'
          parser.separator ""
          parser.separator "Options:"
        
          parser.on('-a', '--address HOST',    'bind to HOST address (default: 0.0.0.0)')      { |value| @options[:host] = value }
          parser.on('-p', '--port PORT',       'use PORT (default: 3000)')                     { |value| @options[:port] = value.to_i }
          parser.on('-d', '--daemonize',       'run as daemon')                                { |value| @options[:daemonize] = true }
          parser.on('-l', '--log FILE' ,       'log file')                                     { |value| @options[:log_file] = value }

          parser.separator ""
          parser.separator "Commands: #{COMMANDS.join(', ')}"
        
          parser.parse!
        end

        @command = argv.shift
        @command &&= @command.to_sym
      end
    end
  end
end
