module ThreeScale
  module Backend
    class Storage
      def initialize
        config = ThreeScale::Backend.configuration.redis || {}

        # TODO: Implement proper failover.
        servers = config['servers'] || []
        server = servers.first || '127.0.0.1:6379'

        @host, @port = server.split(':')
        @db = config['db']
      end

      def connection
        @connection ||= begin
                          connection = EventMachine::Protocols::Redis.connect(@host, @port)
                          connection.select(@db) if @db
                          connection
                        end
      end

      def incrby_and_expire(key, value, expires_in, &block)
        incrby(key, value) do
          expire(key, expires_in, &block)
        end
      end

      def method_missing(name, *args, &block)
        connection.send(name, *args, &block)
      end
    end

    def self.storage
      @storage ||= Storage.new
    end
  end
end
