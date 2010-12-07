require 'optparse'

module ThreeScale
  module Backend
    module Runner
      extend self

      DEFAULT_OPTIONS = {:host => '0.0.0.0', :port => 3000}
      COMMANDS = [:start, :stop, :restart, :restore_backup, :archive]

      def run
        send(*parse!(ARGV))
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

      def archive(options)
        Archiver.store(options.merge(:tag => `hostname`.strip))
        Archiver.cleanup
      end

      private

      def parse!(argv)
        options = DEFAULT_OPTIONS

        parser = OptionParser.new do |parser|
          parser.banner = 'Usage: 3scale_backend [options] command'

          parser.separator "\nOptions for start, stop and restart:"

          parser.on('-p', '--port PORT', 'use PORT (default: 3000)') do |value|
            options[:port] = value.to_i
          end

          parser.separator "\nOptions for start:"

          parser.on('-a', '--address HOST', 'bind to HOST address (default: 0.0.0.0)') do |value|
            options[:host] = value
          end

          parser.on('-d', '--daemonize', 'run as daemon') do |value|
            options[:daemonize] = true
          end

          parser.on('-l', '--log FILE', 'log file') do |value|
            options[:log_file] = value
          end

          parser.separator "\nOptions for archive:"

          parser.on('--aws-access-key-id STRING', 'AWS access key id') do |value|
            options[:access_key_id] = value
          end

          parser.on('--aws-secret-access-key STRING', 'AWS secret access key') do |value|
            options[:secret_access_key] = value
          end

          parser.separator ""
          parser.separator "Commands: #{COMMANDS.join(', ')}"

          parser.parse!
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
