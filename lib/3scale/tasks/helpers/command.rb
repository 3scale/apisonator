module ThreeScale
  module Tasks
    module Helpers
      module Command
        module_function

        # Use this to block on running short-lived commands where no progress
        # needs to be taken from outputs and the output size is allocatable in a
        # string big enough.
        #
        # Use raise_unless_ok: false if you want to handle failed status.
        #
        # Returns an array of [stdout, stderr, status] or raises a StandardError
        # with methods .stdout, .stderr and .status.
        def run(command, *args,
                stdin_data: '',
                binmode: true,
                raise_unless_ok: true, # true if you just want success
                **opts)
          require 'open3'

          result = Open3.capture3(command, *args,
                                  stdin_data: stdin_data,
                                  binmode: binmode,
                                  **opts)

          status = result[2]

          message = if status.exited?
            return result if !raise_unless_ok || status.success?

            "Failed exit status: #{command}#{args.empty? ?
              '' : ' ' + args.join(' ')}\n" \
              "Status: #{status.exitstatus}\n"
          else
            "Abnormal execution: #{command}#{args.empty? ?
                '' : ' ' + args.join(' ')}\n" \
              "PID: #{status.pid}\n" \
              "Signaled: #{status.signaled? ?
                "yes, sig #{status.termsig.inspect}" : 'no'}\n" \
              "Stopped: #{status.stopped? ?
                "yes, sig #{status.stopsig.inspect}" : 'no'}\n"
          end

          stdout, stderr, = result

          trimmed_out = stdout[-[512, stdout.size].min..-1]
          trimmed_err = stderr[-[512, stdout.size].min..-1]

          message << "stdout (last 512 chars):\n" \
            "#{trimmed_out.empty? ? '(empty)': trimmed_out}\n" \
            "stderr (last 512 chars):\n" \
            "#{trimmed_err.empty? ? '(empty)': trimmed_err}\n" \

          # raise exception, but make status available in its .status method
          raise(StandardError.new(message).tap do |e|
            e.define_singleton_method(:stdout) { stdout }
            e.define_singleton_method(:stderr) { stderr }
            e.define_singleton_method(:status) { status }
          end)
        end
      end
    end
  end
end
