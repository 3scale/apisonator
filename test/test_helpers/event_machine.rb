module TestHelpers
  # Support for testing evented code.
  module EventMachine
    def self.included(base)
      base.class_eval do
        alias_method :run_without_event_machine, :run
        alias_method :run, :run_with_event_machine
      end
    end

    def run_with_event_machine(result, &block)
      ::EventMachine.run do
        run_without_event_machine(result, &block)
        done! if passed? == false
      end
    end

    # Call this in each test method after the last assertion to stop the reactor loop.
    def done!
      ::EventMachine.stop
    end
  end
end
