require 'async/io'
require 'async/redis/client'

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
        DEFAULT_PORT = 22121

        # Custom Redis Protocol class which sends the AUTH command on every new connection
        # to authenticate before sending any other command.
        class AuthenticatedRESP2
          def initialize(credentials)
            @credentials = credentials
          end

          def client(stream)
            client = Async::Redis::Protocol::RESP2.client(stream)

            client.write_request(["AUTH", *@credentials])
            client.read_response # Ignore response.

            client
          end
        end

        def initialize_client(opts)
          endpoint = make_redis_endpoint(opts)
          protocol = make_redis_protocol(opts)
          Async::Redis::Client.new(endpoint, protocol: protocol, limit: opts[:max_connections])
        end

        # Authenticated RESP2 if credentials are provided, RESP2 otherwise
        def make_redis_protocol(opts)
          uri = URI(opts[:url] || "")
          credentials = [ uri.user || opts[:username], uri.password || opts[:password]]

          if credentials.any?
            AuthenticatedRESP2.new(credentials)
          else
            Async::Redis::Protocol::RESP2
          end
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
