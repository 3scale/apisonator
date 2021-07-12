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

          # Redis returns an answer for each of the commands sent in the
          # pipeline. But in order to keep compatibility with redis-rb, here, if
          # there is an error in any of the commands of the pipeline we will
          # raise an error (the first one that occurred).

          first_err = nil

          res = commands.size.times.map do
            begin
              connection.read_response
            rescue ::Protocol::Redis::ServerError => e
              first_err ||= e
              nil
            end
          end

          raise first_err if first_err

          res
        end
      end
    end
  end
end
