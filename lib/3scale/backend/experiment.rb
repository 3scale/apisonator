require 'scientist'
require 'statsd'

module ThreeScale
  module Backend
    # This class allows us to perform experiments using the Scientist gem from
    # GitHub. It is useful for comparing two different behaviors when doing a
    # refactoring. The idea is that we can use the old code in the normal flow
    # of the program and at the same time, we can compare its results and
    # performance against new code. This class notifies the logger if the result
    # of the two fragments of code does not match. Also, it sends their
    # execution time to StatsD.
    #
    # To use this class, you need to declare the old behavior in a 'use' block,
    # and the new one in a 'try' block. Also, when instantiating the class, we
    # need to give the experiment a name, and define the % of times that it
    # will run.
    # exp = ThreeScale::Backend::Experiment.new('my-experiment', 50)
    # exp.use { old_method }
    # exp.try { new_method }
    # exp.run
    #
    # 'run' returns the result of the block sent to the 'use' method. Its
    # return value is the one we should use in our program. On the other hand,
    # 'try' will swallow any exception raised inside the block. The operations
    # inside the 'try' block should be idempotent. Avoid operations like
    # writing to the DB.

    class Experiment
      include Scientist::Experiment
      include Backend::Logging

      ResultsMismatch = Class.new(StandardError)

      RANDOM = Random.new
      private_constant :RANDOM

      def initialize(name, perc_exec)
        @name = name
        @perc_exec = perc_exec
        @base_metric = "backend.#{environment}.experiments.#{name}"
      end

      def publish(result)
        # This only works for the first candidate (try block)
        send_to_statsd(result.control.duration, result.candidates.first.duration)
        check_mismatch(result)
      end

      def enabled?
        RANDOM.rand(100) < perc_exec
      end

      private

      attr_reader :name, :perc_exec, :base_metric

      def send_to_statsd(control_duration, candidate_duration)
        statsd.timing("#{base_metric}.control", control_duration)
        statsd.timing("#{base_metric}.candidate", candidate_duration)
      end

      def check_mismatch(result)
        if result.mismatched?
          msg = mismatch_msg(result.control.value, result.candidates.first.value)
          logger.notify(ResultsMismatch.new(msg))
        end
      end

      def mismatch_msg(control_value, candidate_value)
        "There was a mismatch when running the experiment #{name}. "\
        "control = #{control_value}, candidate = #{candidate_value}''"
      end

      def statsd
        Statsd.instance
      end

      def environment
        ThreeScale::Backend.environment
      end
    end
  end
end
