module TestHelpers
  # Support for testing evented code.
  module EventMachine

    module Methods
      def in_event_machine_loop
        result = nil

        EM.run do
          Fiber.new do
            result = yield
            EM.stop
          end.resume
        end

        result
      end
    end

    include Methods

    def self.included(base)
      base.class_eval do
        alias_method :run_without_event_machine, :run
        alias_method :run, :run_with_event_machine
      end
    end

    def run_with_event_machine(runner, &block)
      in_event_machine_loop { run_without_event_machine(runner, &block) }
    end
  end
end
