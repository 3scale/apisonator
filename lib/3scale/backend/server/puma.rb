# puma.rb - Class handling Puma application server details
#
# Note that:
#
# This class has its own default ideas about some settings that you can
# override through command line switches.
#
require 'puma/cli'

module ThreeScale
  module Backend
    class Server
      class Puma
        CONTROL_URL = 'unix:///tmp/3scale_backend.sock'
        STATE_PATH = '/tmp/3scale_backend.state'

        class << self
          attr_reader :cli

          def new(options)
            puma_argv = options[:argv] || []

            if options[:Host]
              puma_argv << ['-b', "tcp://#{options[:Host]}:#{options[:Port] || 3000}"]
            elsif options[:Port]
              puma_argv << ['-p', options[:Port]]
            end

            arg_add puma_argv, '--daemon', '-d', true unless options[:daemonize].nil?
            arg_add puma_argv, '--pidfile', options[:pid] unless options[:pid].nil?

            # serving model settings here
            #
            # currently just a cluster of CPUs + 1 workers
            arg_add puma_argv, '--threads', '-t', '1:1'
            arg_add puma_argv, '--workers', '-w', (ThreeScale::Backend.number_of_cpus + 1)

            # additional settings here
            arg_add puma_argv, '--tag', (options[:tag] || name)
            arg_add puma_argv, '--state', '-S', STATE_PATH
            arg_add puma_argv, '--control', CONTROL_URL
            arg_add puma_argv, '--dir', ThreeScale::Backend.root_dir

            log_file = if options[:log_file]
                         if options[:error_file].nil? && ThreeScale::Backend.production?
                           options[:error_file] = options[:log_file] + '.err'
                         end
                         open_log_file options[:log_file]
                       else
                         STDOUT
                       end

            error_file = if options[:error_file]
                           open_log_file options[:error_file]
                         else
                           STDERR
                         end

            # rackup file goes last
            puma_argv << [options[:config]] unless options[:config].nil?

            @cli = ::Puma::CLI.new(puma_argv.flatten, ::Puma::Events.new(log_file, error_file))
            self
          end

          def start
            yield self if block_given?
            @cli.run
          end

          [:halt, :restart, :phased_restart,
           :stats, :status, :stop, :reload_worker_directory].each do |cmd|
            define_method cmd do |options|
              command = __method__.to_s.tr('_', '-')
              command = 'phased-restart' if command == 'restart'
              Process.exec "#{build_pumactl_cmd(options)} #{command}"
            end
          end

          private

          def arg_add(argv, *switches, value)
            to_add = [switches.first]
            to_add << value.to_s unless value == true
            argv << to_add unless switches.any? { |s| argv.include?(s) }
          end

          def build_pumactl_cmd(options)
            args = options[:argv] || []
            arg_add args, '-F', '--config-file', config_file
            arg_add args, '-P', '--pidfile', options[:pid]
            arg_add args, '-C', '--control-url', CONTROL_URL
            arg_add args, '-S', '--state', STATE_PATH
            "pumactl #{args.flatten.join(' ')}"
          end

          def config_file
            base = ThreeScale::Backend.root_dir + '/config/' + to_s.split(':').last.downcase
            ['/' + ThreeScale::Backend.environment, ''].each do |entry|
              file = base + entry + '.rb'
              return file if File.readable? file
            end
            raise 'cannot find configuration file for Puma'
          end

          def open_log_file(file)
            File.open file, File::CREAT | File::WRONLY | File::APPEND
          end
        end
      end

    end
  end
end
