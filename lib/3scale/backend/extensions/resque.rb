module ThreeScale
  module Backend
    # This module was introduced because of performance reasons.
    # Resque allows us to define some methods that can act like hooks. Those
    # can be executed before a resque job, after it, etc.
    # The problem is that in old versions of Resque, .methods was called on a
    # job class each time a resque job of that class was executed to find those
    # hook methods. If we assume that the methods of a job class will not
    # change in runtime, this seems pretty inefficient.
    # This was solved in a newer version of Resque. Once we update, this module
    # will no longer be necessary. See
    # https://github.com/resque/resque/commit/18ae5b223fe20583b85be2b5dd23abd4c2314dbb
    module ResqueHacks
      
        def before_hooks(job)
          memoized_methods(job).grep(/^before_perform/).sort
        end

        # Given an object, returns a list `around_perform` hook names.
        def around_hooks(job)
          memoized_methods(job).grep(/^around_perform/).sort
        end

        # Given an object, returns a list `after_perform` hook names.
        def after_hooks(job)
          memoized_methods(job).grep(/^after_perform/).sort
        end

        # Given an object, returns a list `on_failure` hook names.
        def failure_hooks(job)
          
         memoized_methods(job).grep(/^on_failure/).sort
        end

        # Given an object, returns a list `after_enqueue` hook names.
        def after_enqueue_hooks(job)
          memoized_methods(job).grep(/^after_enqueue/).sort
        end

        def memoized_methods(job)
          @@methods ||= Hash.new
          methods = @@methods[job.to_s]
          if methods.nil?
            methods = job.methods
            @@methods[job.to_s] = methods
          end
          methods
        end
    end    
  end
end

module Resque
  module Plugin
    extend(ThreeScale::Backend::ResqueHacks)
    include(ThreeScale::Backend::ResqueHacks)
  end
end