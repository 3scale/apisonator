require '3scale/backend/version'
require '3scale/backend/util'
require '3scale/backend/server'

module ThreeScale
  module Backend
    module Manifest
      class << self
        LISTENER_WORKERS = 'LISTENER_WORKERS'.freeze
        private_constant :LISTENER_WORKERS
        PUMA_WORKERS = 'PUMA_WORKERS'.freeze
        private_constant :PUMA_WORKERS
        PUMA_WORKERS_CPUMULT = 8
        private_constant :PUMA_WORKERS_CPUMULT

        # Thread safety of our application. Turn this on if we ever are MT safe.
        def thread_safe?
          false
        end

        # Compute workers based on LISTENER_WORKERS and PUMA_WORKERS env
        # variables. The former takes precedence.
        # If those envs do not exist or are empty, use number of cpus
        def compute_workers(ncpus)
          return 0 unless Process.respond_to?(:fork)

          compute_workers_from_env(LISTENER_WORKERS) ||
            compute_workers_from_env(PUMA_WORKERS) ||
            ncpus * PUMA_WORKERS_CPUMULT
        end

        def server_model
          # Serving model settings here
          #
          # compute default workers and threads values
          # We want to adapt workers and threads to our characteristics.
          # Note that these values will likely need to be tweaked depending on
          # the Ruby implementation and how our app behaves!
          ncpus = ThreeScale::Backend::Util.number_of_cpus
          workers = compute_workers ncpus
          # if no workers but mt-safe, we spawn more threads.
          min_threads, max_threads = if thread_safe?
                                       shift = workers.zero? ? 2 : 0
                                       [ncpus << shift, ncpus << 1 + shift]
                                     else
                                       [1, 1]
                                     end
          {
            ncpus: ncpus,
            workers: workers,
            min_threads: min_threads,
            max_threads: max_threads
          }
        end

        def report
          {
            version: ThreeScale::Backend::VERSION,
            root_dir: ThreeScale::Backend::Util.root_dir,
            servers: ThreeScale::Backend::Server.list,
            thread_safe: thread_safe?,
            server_model: server_model,
          }
        end

        private

        def compute_workers_from_env(env_name)
          if ENV[env_name] && !ENV[env_name].empty?
            begin
              Integer(ENV[env_name])
            rescue => e
              raise e, "#{env_name} environment var cannot be parsed: #{e.message}"
            end
          end
        end
      end
    end
  end
end
