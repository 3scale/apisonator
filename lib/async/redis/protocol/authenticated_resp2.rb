# frozen_string_literal: true

require 'async/redis/protocol/resp2'

module Async
  module Redis
    module Protocol

      # Custom Redis Protocol class which sends the AUTH command on every new connection
      # to authenticate before sending any other command.
      class AuthenticatedRESP2
        def initialize(db: 0, credentials: [])
          @db = db
          @credentials = credentials
        end

        def client(stream)
          client = Async::Redis::Protocol::RESP2.client(stream)

          if @credentials.any?
            client.write_request(["AUTH", *@credentials])
            client.read_response # Ignore response.
          end

          if @db
            client.write_request(["SELECT", @db])
            client.read_response
          end

          client
        end
      end
    end
  end
end
