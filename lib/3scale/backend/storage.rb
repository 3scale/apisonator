module ThreeScale
  module Backend
    class Storage
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

      class << self
        # Returns a shared instance of the storage. If there is no instance yet,
        # creates one first. If you want to always create a fresh instance, set
        # the +reset+ parameter to true.
        def instance(reset = false)
          @@instance = nil if reset
          @@instance ||= begin
                           host, port = Helpers.host_and_port(
                                          configuration.redis.proxy || DEFAULT_SERVER)
                           new(host: host, port: port)
                         end
        end

        private

        def new(options)
          options = Helpers.config_with(configuration.redis, options)
          Redis.new options
        end

        # for testing we need to return a wrapper that catches some specific
        # commands so that they are sent to shards instead to a proxy, because
        # the proxy lacks support for those (these are typically commands to
        # flush the contents of the database).
        if ThreeScale::Backend.test?
          alias_method :orig_new, :new

          def new(options)
            TestRedis.new orig_new(options)
          end

          def non_proxied_instances
            @non_proxied_instances ||= configuration.redis.nodes.map do |server|
              host, port = Helpers.host_and_port(server)
              options = Helpers.config_with(configuration.redis, host: host, port: port)
              orig_new(options)
            end
          end
          public :non_proxied_instances

        end
      end
    end

    if ThreeScale::Backend.test?
      # a wrapper class for the Redis client used in tests so that we can
      # address specific Redis instances (as compared to proxies) for flushing.
      class TestRedis
        def initialize(inner_client)
          @inner = inner_client
        end

        def keys(*keys)
          non_proxied_instances.map do |i|
            i.keys(*keys)
          end.flatten(1)
        end

        def flushdb
          non_proxied_instances.map do |i|
            i.flushdb
          end
        end

        def flushall
          non_proxied_instances.map do |i|
            i.flushall
          end
        end

        def method_missing(m, *args, &blk)
          # define and delegate the missing method
          self.class.send(:define_method, m) do |*a, &b|
            inner.send(m, *a, &b)
          end
          inner.send(m, *args, &blk)
        end

        def respond_to_missing?(m)
          inner.respond_to_missing? m
        end

        private

        attr_reader :inner

        def non_proxied_instances
          ThreeScale::Backend::Storage.non_proxied_instances
        end
      end
    end
  end
end
