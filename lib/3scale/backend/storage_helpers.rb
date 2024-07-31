module ThreeScale
  module Backend
    module StorageHelpers
      private
      def encode(stuff)
        Yajl::Encoder.encode(stuff)
      end

      def decode(encoded_stuff)
        stuff = Yajl::Parser.parse(encoded_stuff).symbolize_names
        stuff[:timestamp] = Time.parse_to_utc(stuff[:timestamp]) if stuff[:timestamp]
        stuff
      end

      def storage
        Storage.instance
      end
    end

    class Storage
      Error = Class.new StandardError

      # this is a private error
      UnspecifiedURIScheme = Class.new Error
      private_constant :UnspecifiedURIScheme

      class UnspecifiedURI < Error
        def initialize
          super "Redis URL not specified with url, " \
                  "proxy, server or default_url."
        end
      end

      class InvalidURI < Error
        def initialize(url, error)
          super "The provided URL #{url.inspect} is not valid: #{error}"
        end
      end

      module Helpers
        class << self
          # CONN_OPTIONS - Redis client default connection options
          CONN_OPTIONS = {
              connect_timeout: 5,
              read_timeout: 3,
              write_timeout: 3,
              # Note that we can set reconnect_attempts to >= 0 because we use
              # a monkey patch which implements a workaround for this issue
              # that shows that there might be duplicated transactions when
              # there's a timeout: https://github.com/redis/redis-rb/issues/668
              # We should investigate if there are edge cases that can lead to
              # duplicated commands because of this setting.
              reconnect_attempts: 1,
              # applies only to async mode. Use the C extension client by default
              driver: :hiredis,
              # applies only to async mode. The sync library opens 1 connection
              # per process.
              max_connections: 10,
          }.freeze
          private_constant :CONN_OPTIONS

          # CONN_WHITELIST - Connection options that can be specified in config
          # Note: we don't expose reconnect_attempts until the bug above is fixed
          CONN_WHITELIST = [
            :connect_timeout, :read_timeout, :write_timeout, :max_connections, :username, :password, :sentinel_username,
            :sentinel_password, :ssl, :ssl_params
          ].freeze
          private_constant :CONN_WHITELIST

          # Parameters regarding target server we will take from a config object
          URL_WHITELIST = [:url, :proxy, :server, :sentinels, :role].freeze
          private_constant :URL_WHITELIST

          # these are the parameters we will take from a config object
          CONFIG_WHITELIST = (URL_WHITELIST + CONN_WHITELIST).freeze
          private_constant :CONFIG_WHITELIST

          DEFAULT_SENTINEL_PORT = 26379
          private_constant :DEFAULT_SENTINEL_PORT

          # Generate an options hash suitable for Redis.new's constructor
          #
          # The options hash will overwrite any settings in the configuration,
          # and will also accept a special "default_url" parameter to apply when
          # no URL-related parameters are passed in (both in configuration and
          # in options).
          #
          # The whitelist and defaults keyword parameters control the
          # whitelisted configuration keys to add to the Redis parameters and
          # the default values for unspecified keys. This way you don't need to
          # rely on hardcoded defaults.
          def config_with(config,
                          options: {},
                          whitelist: CONFIG_WHITELIST,
                          defaults: CONN_OPTIONS)
            cfg_options = parse_dbcfg(config)
            cfg = whitelist.each_with_object({}) do |k, h|
              val = cfg_options[k]
              h[k] = val if val
            end.merge(options)

            cfg_compacted = cfg_compact cfg
            cfg_with_sentinels = cfg_sentinels_handler cfg_compacted
            cfg_defaults_handler cfg_with_sentinels, defaults
          end

          private

          # Takes an object that can be converted to a Hash and returns a
          # suitable options hash for using with our constructor.
          #
          # This is intended to be called on configuration objects for our
          # database only, since it assumes that nil values need to be thrown
          # out, but can also be used with hashes if you are ok with removing
          # keys with nil values.
          #
          # Does not modify the original object.
          def parse_dbcfg(dbcfg)
            if !dbcfg.is_a? Hash
              raise "can't convert #{dbcfg.inspect} to a Hash" if !dbcfg.respond_to? :to_h

              dbcfg = dbcfg.to_h
            end

            # unfortunately the current config object translates blank (not
            # filled in) configuration options to nil, so we can't distinguish
            # between non-specification and an actual nil value - so remove
            # them to avoid overriding default values with nils.
            dbcfg.reject do |_, v|
              v.nil?
            end
          end

          def to_redis_uri(maybe_uri)
            raise UnspecifiedURI if maybe_uri.nil?
            raise InvalidURI.new(maybe_uri, 'empty URL') if maybe_uri.empty?

            begin
              validate_redis_uri maybe_uri
            rescue URI::InvalidURIError, UnspecifiedURIScheme => e
              begin
                validate_redis_uri 'redis://' + maybe_uri
              rescue
                # tag and re-raise the original error to avoid confusion
                raise InvalidURI.new(maybe_uri, e)
              end
            rescue => e
              # tag exception
              raise InvalidURI.new(maybe_uri, e)
            end
          end

          # Helper for the method above
          #
          # This raises unless maybe_uri is a valid URI.
          def validate_redis_uri(maybe_uri)
            # this might raise URI-specific exceptions
            parsed_uri = URI.parse maybe_uri
            # the parsing can succeed without scheme, so check for it and try
            # to correct the URI.
            raise UnspecifiedURIScheme if parsed_uri.scheme.nil?
            # Check when host is parsed as scheme
            raise URI::InvalidURIError if parsed_uri.host.nil? && parsed_uri.path.nil?

            # return validated URI
            maybe_uri
          end

          # This ensures we always use the :url parameter (and removes others)
          def ensure_url_param(options)
            proxy = options.delete :proxy
            server = options.delete :server
            default_url = options.delete :default_url

            # order of preference: url, proxy, server, default_url
            options[:url] = [options[:url], proxy, server, default_url].find do |val|
              val && !val.empty?
            end

            # not having a :url parameter at this point will throw up an
            # exception when validating the url
            options[:url] = to_redis_uri(options[:url])

            options
          end

          def cfg_compact(options)
            empty = ->(_k,v) { v.to_s.strip.empty? }
            options[:ssl_params]&.delete_if(&empty)
            options.delete_if(&empty)
          end

          # Expected sentinel input cfg format:
          #
          # Either a String with one or more URLs:
          #   "redis_url0,redis_url1,redis_url2,....,redis_urlN"
          # Or an Array of Strings representing one URL each:
          #   ["redis_url0", "redis_url1", ..., "redis_urlN"]
          # When using the String input, the comma "," character is the
          # delimiter between URLs and the "\" character is the escaper that
          # allows you to include commas "," and any other character verbatim in
          # a URL.
          #
          # Parse to expected format by redis client
          # {
          #   sentinels: [
          #     { host: "host0", port: "port0" },
          #     { host: "host1", port: "port1" },
          #     { host: "host2", port: "port2" },
          #     ...
          #     { host: "hostN", port: "portN" }
          #   ],
          #   role: :master,
          #   sentinel_username: "user",
          #   sentinel_password: "password"
          # }
          def cfg_sentinels_handler(options)
            # get role attr and remove from options
            # will only be validated and included when sentinels are valid
            role = options.delete :role
            sentinels = options.delete :sentinels
            # The Redis client can't accept empty string or array of :sentinels
            return options if sentinels.to_s.strip.empty? || sentinels.empty?

            sentinels = Splitter.split(sentinels) if sentinels.is_a? String

            sentinel_user = nil
            sentinel_password = nil
            sentinels = sentinels.map do |sentinel|
              next if sentinel.nil?

              if sentinel.respond_to? :strip!
                sentinel.strip!
                # invalid string if it's empty after stripping
                next if sentinel.empty?
              end

              valid_uri_str = to_redis_uri(sentinel)
              # it is safe to perform URI parsing now
              uri = URI.parse valid_uri_str

              sentinel_user ||= uri.user
              sentinel_password ||= uri.password
              { host: uri.host, port: uri.port }
            end.compact

            return options if sentinels.empty?

            options[:sentinels] = sentinels

            # For the sentinels that do not have the :port key or
            # the port key is nil we configure them with the default
            # sentinel port
            options[:sentinels].each do |sentinel|
              sentinel[:port] ||= DEFAULT_SENTINEL_PORT
            end

            # Handle role option when sentinels are validated
            options[:role] = role if role && !role.empty?

            # Sentinel credentials
            options[:sentinel_username] = sentinel_user unless sentinel_user.to_s.strip.empty?
            options[:sentinel_password] = sentinel_password unless sentinel_password.to_s.strip.empty?

            options
          end

          # The new Redis client accepts either `:url` or `:path`, but not both.
          # In the case of a path, Redis expects it to not include the `unix://` prefix.
          # On the other hand, Apisonator accepts only `:url`, for both Sockets and TCP connections.
          # For paths, Apisonator expects it to be given as a URL using the `unix://` scheme.
          #
          # This method handles the conversion.
          def cfg_unix_path_handler(options)
            if options.key? :path
              options.delete(:url)
              return options
            end

            if options[:url].start_with? "unix://"
              options[:path] = options.delete(:url).delete_prefix("unix://")
            end

            options
          end

          # This ensures some default values are valid for the redis client.
          # In particular:
          #
          # - The :url key is always present
          #   - Except when connecting to a unix socket
          # - :max_connections is only present for async mode
          def cfg_defaults_handler(options, defaults)
            cfg_with_defaults = defaults.merge(ensure_url_param(options))
            cfg_with_defaults = cfg_unix_path_handler(cfg_with_defaults)
            cfg_with_defaults.delete(:max_connections) unless options[:async]
            cfg_with_defaults[:ssl] ||= true if URI(options[:url].to_s).scheme == 'rediss'
            cfg_with_defaults
          end

          # split a string by a delimiter character with escaping
          module Splitter
            def self.split(str, delimiter: ',', escaper: '\\')
              escaping = false

              str.each_char.inject(['']) do |ary, c|
                if escaping
                  escaping = false
                  ary.last << c
                elsif c == delimiter
                  ary << ''
                elsif c == escaper
                  escaping = true
                else
                  ary.last << c
                end

                ary
              end
            end
          end
          private_constant :Splitter
        end
      end
    end
  end
end
