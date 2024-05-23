require 'async/io'
require 'async/redis/client'
require '3scale/backend/async_redis/sentinels_client_acl_tls'
require '3scale/backend/async_redis/protocol/extended_resp2'

module ThreeScale
  module Backend
    module StorageAsync

      # This is a wrapper for the Async-Redis client
      # (https://github.com/socketry/async-redis).
      # This class overrides some methods to provide the same interface that
      # the redis-rb client provides.
      # This is done to avoid modifying all the model classes which assume that
      # the Storage instance behaves likes the redis-rb client.
      class Client
        include Configurable
        include Methods

        class << self
          attr_writer :instance

          def instance(reset = false)
            if reset || @instance.nil?
              @instance = new(
                  Storage::Helpers.config_with(
                      configuration.redis,
                      options: { default_url: "#{DEFAULT_HOST}:#{DEFAULT_PORT}" }
                  )
              )
            else
              @instance
            end
          end
        end

        def initialize(opts)
          @redis_async = initialize_client(opts)
        end

        def call(*args)
          @redis_async.call(*args)
        end

        # This method allows us to send pipelines like this:
        # storage.pipelined do |pipeline|
        #   pipeline.get('a')
        #   pipeline.get('b')
        # end
        def pipelined(&block)
          # This replaces the client with a Pipeline that accumulates the Redis
          # commands run in a block and sends all of them in a single request.

          pipeline = Pipeline.new
          block.call pipeline
          pipeline.run(@redis_async)
        end

        def close
          @redis_async.close
        end

        private

        DEFAULT_SCHEME = 'redis'
        DEFAULT_HOST = 'localhost'.freeze
        DEFAULT_PORT = 6379

        def initialize_client(opts)
          return init_host_client(opts) unless opts.key? :sentinels

          init_sentinels_client(opts)
        end

        def init_host_client(opts)
          endpoint = make_redis_endpoint(opts)
          protocol = make_redis_protocol(opts)
          Async::Redis::Client.new(endpoint, protocol: protocol, limit: opts[:max_connections])
        end

        def init_sentinels_client(opts)
          uri = URI(opts[:url] || '')
          name = uri.host
          role = opts[:role] || :master
          protocol = make_redis_protocol(opts)

          ThreeScale::Backend::AsyncRedis::SentinelsClientACLTLS.new(name, opts[:sentinels], role, protocol, opts)
        end

        # RESP2 with support for logical DBs
        def make_redis_protocol(opts)
          uri = URI(opts[:url] || "")
          db = uri.path[1..-1]
          credentials = [ uri.user || opts[:username], uri.password || opts[:password]]

          ThreeScale::Backend::AsyncRedis::Protocol::ExtendedRESP2.new(db: db, credentials: credentials)
        end

        # SSL endpoint if scheme is `rediss:`, TCP endpoint otherwise.
        # Note: Unix socket endpoint is not supported in async mode
        def make_redis_endpoint(opts)
          uri = URI(opts[:url] || "")
          scheme = uri.scheme || DEFAULT_SCHEME
          host = uri.host || DEFAULT_HOST
          port = uri.port || DEFAULT_PORT

          tcp_endpoint = Async::IO::Endpoint.tcp(host, port)

          case scheme
          when 'redis'
            tcp_endpoint
          when 'rediss'
            ssl_context = OpenSSL::SSL::SSLContext.new
            ssl_context.set_params(format_ssl_params(opts[:ssl_params]))
            Async::IO::SSLEndpoint.new(tcp_endpoint, ssl_context: ssl_context)
          else
            raise ArgumentError
          end
        end

        def format_ssl_params(ssl_params)
          cert = ssl_params[:cert].to_s.strip
          key = ssl_params[:key].to_s.strip
          return ssl_params if cert.empty? && key.empty?

          updated_ssl_params = ssl_params.dup
          updated_ssl_params[:cert] = OpenSSL::X509::Certificate.new(File.read(cert))
          updated_ssl_params[:key] = OpenSSL::PKey.read(File.read(key))

          updated_ssl_params
        end
      end
    end
  end
end
