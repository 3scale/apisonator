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
        STATE_PATH = '/tmp/3scale_backend.state'
        CONTROL_URL = 'unix:///tmp/3scale_backend.sock'
        CONTROL_AUTH_TOKEN = :none # set to :none, nil for random, or value

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
            arg_add puma_argv, '--tag', options[:tag] unless options[:tag].nil?

            # rackup file goes last
            puma_argv << [options[:config]] unless options[:config].nil?

            puma_config_hack! options[:log_file], '2.13.4'

            @cli = ::Puma::CLI.new(puma_argv.flatten)

            # Puma makes a lot of assumptions regarding how it is being run. In
            # particular, Puma::CLI thinks it is alone in the world. We have
            # to override them, because otherwise it will try to restart us
            # dropping the 3scale_backend's runner-specific arguments and using
            # Puma's own knobs, which will obviously not work.
            puma_restart_argv = @cli.instance_variable_get('@restart_argv')
            arg_3scalebe = puma_restart_argv.reverse.find do |arg|
              arg.end_with? '3scale_backend'
            end
            if arg_3scalebe
              idx_3scalebe = puma_restart_argv.rindex(arg_3scalebe)
              puma_restart_argv[idx_3scalebe+1..-1] = options[:original_argv] if idx_3scalebe
            end

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

          # Puma does not allow us to specify some settings from the CLI
          # interface, so we are forced to override them. The problem is that by
          # the time the config file is loaded and parsed, it is already too
          # late for us to change anything.
          #
          # So basically we monkey patch some default values that we know we
          # want IN CASE NO ONE SPECIFIED ANYTHING ELSE (ie. not in parameters,
          # not in config file), and we also hook in just after having a final
          # option set so that we can respect the log file parameter.
          #
          # For this to be really accurate, we check the version so that a human
          # has actually looked at their code and made sure this will work.
          def puma_config_hack!(log_file, version)
            raise 'Unknown Puma version' unless version == ::Puma::Const::VERSION

            # Serving model settings here
            #
            # compute default workers and threads values
            # We want to adapt workers and threads to our characteristics.
            # Note that these values will likely need to be tweaked depending on
            # the Ruby implementation and how our app behaves!
            ncpus = ThreeScale::Backend.number_of_cpus
            workers = Process.respond_to?(:fork) ? ncpus + 1 : 0
            # if no workers but mt-safe, we spawn more threads.
            min_threads, max_threads = if ThreeScale::Backend.thread_safe?
                                         shift = workers.zero? ? 2 : 0
                                         [ncpus << shift, ncpus << 1 + shift]
                                       else
                                         [1, 1]
                                       end

            # overwrite some Puma defaults
            ::Puma::Configuration.class_eval do
              alias_method :old_default_options, :default_options
              define_method :default_options do
                old_default_options.merge!(
                  min_threads: min_threads,
                  max_threads: max_threads,
                  workers: workers,
                  # pick up the Backend env
                  environment: ThreeScale::Backend.environment,
                  # operate out of the Backend root dir by default
                  directory: ThreeScale::Backend.root_dir,
                  worker_directory: ThreeScale::Backend.root_dir,
                  # default status and control settings
                  state: STATE_PATH,
                  control_url: CONTROL_URL,
                  control_auth_token: CONTROL_AUTH_TOKEN,
                  # stop Puma from logging each request on its own in dev mode
                  quiet: true
                )
              end
            end

            ::Puma::CLI.class_eval do
              alias_method :old_parse_options, :parse_options
              define_method :parse_options do
                old_parse_options
                # config is a method with the config settings in Puma::CLI
                opts = config.options
                # don't want this to be overriden with a puma config!
                if opts[:environment] != ThreeScale::Backend.environment
                  raise "mismatched environment in Backend vs Puma config file"
                end
                if opts[:max_threads].to_i > 1 && !ThreeScale::Backend.thread_safe?
                  raise "Puma was instructed to use multiple threads, but we are not MT-safe!"
                end
                # the log file parameter has precedence over other settings
                if log_file
                  opts[:redirect_append] = true
                  opts[:redirect_stdout] = log_file
                  opts[:redirect_stderr] = log_file
                end
              end
            end
          end

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
            # add control token if it is set and not autogenerated
            if CONTROL_AUTH_TOKEN && CONTROL_AUTH_TOKEN != :none
              arg_add args, '-T', '--control-token', CONTROL_AUTH_TOKEN
            end
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
        end
      end

    end
  end
end
