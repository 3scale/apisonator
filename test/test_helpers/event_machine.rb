module TestHelpers
  # Support for testing evented code.
  module EventMachine
    def self.included(base)
      base.class_eval do
        alias_method :run_without_event_machine, :run
        alias_method :run, :run_with_event_machine
      end
    end

    def run_with_event_machine(runner, &block)
      result = nil
     
      ::EventMachine.run do
        Fiber.new do
          result = run_without_event_machine(runner, &block)
          ::EventMachine.stop
        end.resume
      end

      result
    end
  end
end
