module ThreeScale
  module Backend
    class Storage < ::Redis
      include Configurable

      DEFAULT_SERVER = '127.0.0.1:22121'

      # Returns a shared instance of the storage. If there is no instance yet,
      # creates one first. If you want to always create a fresh instance, set the
      # +reset+ parameter to true.
      def self.instance(reset = false)
        @@instance = nil if reset
        @@instance ||= new(server: configuration.redis.proxy)

        @@instance
      end

      def host_and_port(server)
        host, port = server.split(':')
        port       = port.to_i

        [host, port]
      end

      def initialize(options)
        host, port = host_and_port(options[:server] || DEFAULT_SERVER)

        super(host: host, port: port, driver: :hiredis)
      end

      def non_proxied_instances
        if ENV['RACK_ENV'] != 'test'
          raise "You only can use this method in a TEST environment."
        end

        @non_proxied_instances ||= configuration.redis.nodes.map do |server|
          host, port = host_and_port(server)

          Redis.new(host: host, port: port, driver: :hiredis)
        end
      end

      def keys(*keys)
        non_proxied_instances.map { |instance| instance.keys(*keys) }.flatten(1)
      end

      def flushdb
        non_proxied_instances.map(&:flushdb)
      end

      def flushall
        non_proxied_instances.map(&:flushall)
      end
    end
  end
end
