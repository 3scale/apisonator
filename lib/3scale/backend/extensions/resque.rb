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
      # A method becomes a resque hook if its name starts with a determined
      # prefix.
      HOOKS = { before_hooks: 'before_perform'.freeze,
                around_hooks: 'around_perform'.freeze,
                after_hooks: 'after_perform'.freeze,
                failure_hooks: 'on_failure'.freeze,
                after_enqueue_hooks: 'after_enqueue'.freeze }.freeze
      private_constant(:HOOKS)

      HOOKS.keys.each do |hook_type|
        define_method(hook_type) do |job|
          memoized_methods(job)[hook_type]
        end
      end

      private

      def memoized_methods(job)
        @@methods ||= Hash.new
        methods = @@methods[job.to_s]
        if methods.nil?
          methods = categorized_hooks(job.methods)
          @@methods[job.to_s] = methods
        end
        methods
      end

      def categorized_hooks(methods)
        HOOKS.inject({}) do |res, (hook, prefix)|
          res[hook] = methods.select do |method|
            method.to_s.start_with?(prefix)
          end.sort
          res
        end
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