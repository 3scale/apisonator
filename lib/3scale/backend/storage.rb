module ThreeScale
  module Backend
    class Storage
      include Configurable

      def self.instance
        @instance ||= new
      end

      def initialize
        # TODO: Implement proper failover.
        servers = configuration.redis.servers || []
        server  = servers.first || '127.0.0.1:6379'

        host, port = server.split(':')

        @host = host
        @port = port.to_i
        @db   = configuration.redis.db || 0
      end

      def method_missing(name, *args)
        fiber = Fiber.current

        connection.send(name, *args) do |*response|
          fiber.resume(*response)
        end

        Fiber.yield
      end

      ConnectionError = Class.new(RuntimeError)

      private
      
      def connection
        @connection ||= connect
      end

      def connect
        connection = Connection.connect(@host, @port)
        connection.select(@db)
        connection
      end
      
      module Connection
        include EM::Protocols::Redis

        def self.connect(host, port)
          EM.connect(host, port, self, host, port)
        end

        def unbind
          raise ConnectionError, 'redis connection lost' if @connecting
          @connected = false
        end

        def initialize(host, port)
          @host = host
          @port = port

          @connecting = true
        end

        def connection_completed
          super
          @connecting = false
        end

        def raw_call_command(*args, &block)
          raise ConnectionError, 'redis connection lost' unless @connected
          super
        end
      end
    end
  end
end
