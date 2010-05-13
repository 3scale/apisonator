module ThreeScale
  module Backend
    class Storage
      include Configurable
      configuration.register_section(:redis, :servers, :db)

      def initialize
        # TODO: Implement proper failover.
        servers = configuration.redis.servers || []
        server  = servers.first || '127.0.0.1:6379'

        @host, @port = server.split(':')
        @db = configuration.redis.db
      end

      def method_missing(name, *args)
        fiber = Fiber.current

        connection.send(name, *args) do |*response|
          fiber.resume(*response)
        end

        Fiber.yield
      end

      def disconnect
        @connection = nil
      end

      private

      def connect
        connection = Connection.connect(@host, @port, self)
        connection.select(@db) if @db
        connection
      end
      
      def connection
        @connection ||= connect
      end

      # Connection remembers the storage object that contains it, and resets itself
      # when unbound. This is to prevent sending commands to dead connection when
      # the reactor loop was stopped (and possibly stated again).
      module Connection
        include EM::Protocols::Redis

        def self.connect(host, port, storage)
          EM.connect(host, port, self, storage)
        end

        def unbind
          @storage && @storage.disconnect
        end

        def initialize(storage)
          @storage = storage
        end
      end
    end

    def self.storage
      @storage ||= Storage.new
    end
  end
end
