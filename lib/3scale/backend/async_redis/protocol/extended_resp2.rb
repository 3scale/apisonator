# frozen_string_literal: true

require 'async/redis/protocol/resp2'

module ThreeScale
  module Backend
    module AsyncRedis
      module Protocol

        # Custom Redis Protocol supporting Redis logical DBs
        # and ACL credentials
        class ExtendedRESP2

          def initialize(db: nil, credentials: [])
            @db = db
            @credentials = credentials.reject{_1.to_s.strip.empty?}
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
end
