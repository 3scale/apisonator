# Monkey-patches the async-redis lib to provide a 'call_pipeline' method that
# sends multiple commands at once and returns an array of the responses for
# each of them.

module Async
  module Redis
    class Client
      def call_pipeline(commands)
        @pool.acquire do |connection|
          commands.each do |command|
            connection.write_request(command)
          end

          connection.flush

          commands.size.times.map { connection.read_response }
        end
      end
    end
  end
end
