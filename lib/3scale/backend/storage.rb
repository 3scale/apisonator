module ThreeScale
  module Backend
    class Storage < ::Redis
      include Configurable

      DEFAULT_SERVER = '127.0.0.1:22121'.freeze
      private_constant :DEFAULT_SERVER

      module Helpers
        # default values for the Redis client
        CONN_OPTIONS = {
                         connect_timeout: 5,
                         read_timeout: 3,
                         write_timeout: 3,
                         # this is set to zero to avoid potential double transactions
                         # see https://github.com/redis/redis-rb/issues/668
                         reconnect_attempts: 0,
                         # use by default the C extension client
                         driver: :hiredis
                       }.freeze
        private_constant :CONN_OPTIONS

        def self.host_and_port(server)
          host, port = server.split(':')
          [host, port.to_i]
        end

        def self.config_with(config, options)
          options = if config
                      {
                        connect_timeout: config.connect_timeout,
                        read_timeout: config.read_timeout,
                        write_timeout: config.write_timeout
                      }.merge(options)
                    else
                      options
                    end.delete_if do |_, v|
                      v.nil?
                    end
          CONN_OPTIONS.merge(options)
        end
      end

      # Returns a shared instance of the storage. If there is no instance yet,
      # creates one first. If you want to always create a fresh instance, set the
      # +reset+ parameter to true.
      def self.instance(reset = false)
        @@instance = nil if reset
        @@instance ||= begin
                         host, port = Helpers.host_and_port(
                                        configuration.redis.proxy || DEFAULT_SERVER)
                         new(host: host, port: port)
                       end
      end

      def self.max_key_length
        # currently this is hardcoded to be the Twemproxy limit minus
        # additional safety space we reserve for prefixes and potential
        # combination of long parameters (256 bytes)
        # MBUF_SIZE - MBUF_HDR_SIZE - 256
        8192 - 48 - 256
      end

      def initialize(options)
        options = Helpers.config_with(configuration.redis, options)
        super
      end

      def non_proxied_instances
        if ENV['RACK_ENV'] != 'test'
          raise "You only can use this method in a TEST environment."
        end

        @non_proxied_instances ||= configuration.redis.nodes.map do |server|
          host, port = Helpers.host_and_port(server)
          options = Helpers.config_with(configuration.redis, host: host, port: port)
          # Note: as designed this cannot be our own class because
          # flushdb would be recursive.
          Redis.new(options)
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
