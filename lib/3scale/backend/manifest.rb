require '3scale/backend/version'
require '3scale/backend/util'
require '3scale/backend/server'

module ThreeScale
  module Backend
    module Manifest
      class << self
        # Thread safety of our application. Turn this on if we ever are MT safe.
        def thread_safe?
          false
        end

        def server_model
          # Serving model settings here
          #
          # compute default workers and threads values
          # We want to adapt workers and threads to our characteristics.
          # Note that these values will likely need to be tweaked depending on
          # the Ruby implementation and how our app behaves!
          ncpus = ThreeScale::Backend::Util.number_of_cpus
          workers = if Process.respond_to?(:fork)
                      ENV['PUMA_WORKERS'] || ncpus << 3
                    else
                      0
                    end
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
      end
    end
  end
end
