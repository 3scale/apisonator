# Monkey-patches the async-redis lib to provide a 'call_pipeline' method that
# sends multiple commands at once and returns an array of the responses for
# each of them.

module Async
  module Redis
    class Client
      def call_pipeline(commands)
        @pool.acquire do |connection|
          commands.each do |command|
            connection.write_request_without_flush(command)
          end

          connection.flush

          commands.size.times.map { connection.read_response }
        end
      end
    end
  end
end

module Async
  module Redis
    module Protocol
      class RESP

        # This is exactly the same as #write_request but without flushing at
        # the end. It leaves the responsibility of flushing to the caller.
        # This method is useful for pipelining because instead of flushing
        # once per command, we want to flush just once for the whole pipeline
        # for performance reasons.
        def write_request_without_flush(arguments)
          write_lines("*#{arguments.count}")

          arguments.each do |argument|
            string = argument.to_s

            write_lines("$#{string.bytesize}", string)
          end
        end

        def flush
          @stream.flush
        end
      end
    end
  end
end
