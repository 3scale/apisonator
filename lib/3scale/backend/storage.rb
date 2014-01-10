module ThreeScale
  module Backend
    class Storage < ::Redis
      include Configurable

      DEFAULT_SERVER = '127.0.0.1:6379'

      # Returns a shared instance of the storage. If there is no instance yet,
      # creates one first. If you want to always create a fresh instance, set the
      # +reset+ parameter to true.
      def self.instance(reset = false)
        @@instance = nil if reset
        @@instance ||= new(servers: configuration.redis.servers,
                           db:      configuration.redis.db)
        @@instance
      end

      def host_and_port(server)
        host, port = server.split(':')
        port       = port.to_i

        [host, port]
      end

      def initialize(options)
        @servers = options[:servers] || []

        host, port = host_and_port(@servers.first || DEFAULT_SERVER)

        super(host: host, port: port, db: options[:db], driver: :hiredis)
      end
    end
  end
end
