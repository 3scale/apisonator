module ThreeScale
  module Backend
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