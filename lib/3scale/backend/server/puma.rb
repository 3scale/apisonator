module ThreeScale
  module Backend
    module Server
      class Puma
        extend ThreeScale::Backend::Server::Utils

        CONFIG = 'config/puma.rb'
        CONTROL_SOCKET = '3scale_backend.sock'
        STATE = '3scale_backend.state'

        EXPANDED_ROOT_PATH = File.expand_path(File.join(*Array.new(5, '..')),
                                              __FILE__)

        def self.socket_state_dir(env, default_dir)
          if ['development', 'test'].include?(env) && File.writable?(default_dir)
            default_dir
          else
            File.join('', 'tmp')
          end
        end

        def self.start(global_options, options, args)
          manifest = global_options[:manifest]
          return unless manifest
          argv = ['puma']
          argv_add argv, options[:daemonize], '-d'
          argv_add argv, options[:port], '-p', options[:port]
          argv_add argv, options[:logfile], '--redirect-stdout', options[:logfile]
          argv_add argv, options[:errorfile], '--redirect-stderr', options[:errorfile]
          argv << '--redirect-append' if [options[:logfile], options[:errorfile]].any?
          argv_add argv, options[:pidfile], '--pidfile', options[:pidfile]
          # workaround Puma bug not phase-restarting correctly if no --dir is specified
          argv_add argv, true, '--dir', global_options[:directory] ? global_options[:directory] : EXPANDED_ROOT_PATH
          argv_add argv, true, '-C', CONFIG
          ss_dir = socket_state_dir(global_options[:environment], global_options[:directory] || EXPANDED_ROOT_PATH)
          argv_add argv, true, '-S', File.join(ss_dir, STATE)
          argv_add argv, true, '--control', "unix://#{File.join(ss_dir, CONTROL_SOCKET)}"
          server_model = manifest[:server_model]
          argv_add argv, true, '-w', server_model[:workers].to_s
          argv_add argv, true, '-t', "#{server_model[:min_threads]}:#{server_model[:max_threads]}"
        end

        def self.restart(global_options, options, args)
          build_pumactl_cmdline(options[:'phased-restart'] ? 'phased-restart' : 'restart', global_options, options, args)
        end

        [:stop, :status, :stats].each do |cmd|
          define_singleton_method cmd do |global_options, options, args|
            build_pumactl_cmdline(__method__, global_options, options, args)
          end
        end

        def self.help(global_options, options, args)
          system('puma --help')
        end

        def self.build_pumactl_cmdline(cmd, global_options, options, args)
          argv = ['pumactl']
          ss_dir = socket_state_dir(global_options[:environment], global_options[:directory] || EXPANDED_ROOT_PATH)
          argv_add argv, true, '-S', File.join(ss_dir, STATE)
          argv_add argv, true, '-C', "unix://#{File.join(ss_dir, CONTROL_SOCKET)}"
          argv_add argv, true, '-F', CONFIG
          argv << cmd.to_s
          argv
        end
        private_class_method :build_pumactl_cmdline

      end
    end
  end
end
