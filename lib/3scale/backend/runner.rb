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

      COMMANDS = [:start, :stop, :restart, :restore_backup]

      def run
        parse!(ARGV)

        if COMMANDS.include?(@command)
          send(@command)
        else
          if @command
            abort "Unknown command: #{@command}. Use one of: #{COMMANDS.join(', ')}"
          else
            abort @parser.to_s
          end
        end        
      end

      def start
        require 'rack/fiber_pool'
        require '3scale/backend'

        me = self

        server = Thin::Server.new(@options[:host], @options[:port]) do
          # Fiber pool not needed - no async stuff inside
          # use Rack::FiberPool
          
          use HoptoadNotifier::Rack if HoptoadNotifier.configuration
          use Rack::CommonLogger    if me.log?
          use Rack::ContentLength
          use Rack::RestApiVersioning, :default_version => '1.0'
          
          run ThreeScale::Backend::Router.new
        end

        server.pid_file = pid_file
        server.log_file = @options[:log_file] || "/dev/null"

        # Hack to set the process name.
        def server.name
          "3scale_backend listening on #{host}:#{port}"
        end
 
        puts ">> Starting #{server.name} in #{ENV['RACK_ENV']} environment. Let's roll!"

        server.daemonize if @options[:daemonize]
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

        EM.run do
          Fiber.new do
            puts ">> Replaying write commands from backup."
            ThreeScale::Backend::Storage.instance(true).restore_backup
            puts ">> Done."

            EM.stop
          end.resume
        end
      end
      
      def pid_file
        "/tmp/3scale_backend_#{@options[:port]}.pid"
      end

      def log?
        !@options[:daemonize] || @options[:log_file]
      end

      private

      def parse!(argv)
        @parser = OptionParser.new do |parser|
          parser.banner = 'Usage: 3scale_backend [options] command'
          parser.separator ""
          parser.separator "Options:"
        
          parser.on('-a', '--address HOST',    'bind to HOST address (default: 0.0.0.0)')      { |value| @options[:host] = value }
          parser.on('-p', '--port PORT',       'use PORT (default: 3000)')                     { |value| @options[:port] = value.to_i }
          parser.on('-e', '--environment ENV', 'environment to run in (default: development)') { |value| ENV['RACK_ENV'] = value }
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
