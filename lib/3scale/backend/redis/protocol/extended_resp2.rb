# frozen_string_literal: true

require 'async/redis/protocol/resp2'

module ThreeScale
  module Backend
    module Redis
      module Protocol

        # Custom Redis Protocol supporting Redis logical DBs
        class ExtendedRESP2
          def initialize(db: nil)
            @db = db
          end

          def client(stream)
            client = Async::Redis::Protocol::RESP2.client(stream)

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
