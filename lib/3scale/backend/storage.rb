# used to provide a Redis client based on a configuration object
require 'uri'

module ThreeScale
  module Backend
    class Storage
      include Configurable

      Error = Class.new StandardError

      # this is a private error
      UnspecifiedURIScheme = Class.new Error
      private_constant :UnspecifiedURIScheme

      # Constant used for when batching of operations
      # is desired/needed. Batching is performed when a lot
      # of storage operations are need to be performed and we
      # want to minimize database blocking of other clients
      BATCH_SIZE = 400

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
                           # this is set to zero to avoid potential double transactions
                           # see https://github.com/redis/redis-rb/issues/668
                           reconnect_attempts: 0,
                           # use by default the C extension client
                           driver: :hiredis
                         }.freeze
          private_constant :CONN_OPTIONS

          # CONN_WHITELIST - Connection options that can be specified in config
          # Note: we don't expose reconnect_attempts until the bug above is fixed
          CONN_WHITELIST = [:connect_timeout, :read_timeout, :write_timeout].freeze
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

            cfg_with_sentinels = cfg_sentinels_handler cfg

            defaults.merge(ensure_url_param(cfg_with_sentinels))
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

          # Expected sentinel input cfg format:
          #
          # Either a String with one or more URLs:
          #   "redis_url0,redis_url1,redis_url2,....,redis_urlN"
          # Or an Array of Strings representing one URL each:
          #   ["redis_url0", "redis_url1", ..., "redis_urlN"]
          # Or an Array of Hashes with ":host", ":port", and ":password" (optional) keys:
          #   [{ host: "srv0", port: 7379 }, { host: "srv1", port: 7379, password: "abc" }, ...]
          #
          # When using the String input, the comma "," character is the
          # delimiter between URLs and the "\" character is the escaper that
          # allows you to include commas "," and any other character verbatim in
          # a URL.
          #
          # Parse to expected format by redis client
          # [
          #   { host: "host0", port: "port0" },
          #   { host: "host1", port: "port1" },
          #   { host: "host2", port: "port2", password: "abc" },
          #   ...
          #   { host: "hostN", port: "portN" }
          # ]
          def cfg_sentinels_handler(options)
            # get role attr and remove from options
            # will only be validated and included when sentinels are valid
            role = options.delete :role
            sentinels = options.delete :sentinels
            # The Redis client can't accept empty string or array of :sentinels
            return options if sentinels.nil? || sentinels.empty?

            sentinels = Splitter.split(sentinels) if sentinels.is_a? String

            options[:sentinels] = sentinels.map do |sentinel|
              if sentinel.is_a? Hash
                next if sentinel.empty?
                sentinel.fetch(:host) do
                  raise InvalidURI.new("(sentinel #{sentinel.inspect})",
                                       'no host given')
                end
                sentinel
              else
                sentinel_to_hash sentinel
              end
            end.compact

            # For the sentinels that do not have the :port key or
            # the port key is nil we configure them with the default
            # sentinel port
            options[:sentinels].each do |sentinel|
              sentinel[:port] ||= DEFAULT_SENTINEL_PORT
              sentinel.delete(:password) if sentinel[:password].nil? || sentinel[:password].empty?
            end

            # Handle role option when sentinels are validated
            options[:role] = role if role && !role.empty?
            options
          end

          # helper to convert a sentinel object to a Hash
          def sentinel_to_hash(sentinel)
            return if sentinel.nil?

            if sentinel.respond_to? :strip!
              sentinel.strip!
              # invalid string if it's empty after stripping
              return if sentinel.empty?
            end

            valid_uri_str = to_redis_uri(sentinel)
            # it is safe to perform URI parsing now
            uri = URI.parse valid_uri_str

            { host: uri.host, port: uri.port, password: uri.password }
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

      class << self
        # Returns a shared instance of the storage. If there is no instance yet,
        # creates one first. If you want to always create a fresh instance, set
        # the +reset+ parameter to true.
        def instance(reset = false)
          if reset || @instance.nil?
            @instance = new(Helpers.config_with(configuration.redis,
                            options: get_options))
          else
            @instance
          end
        end

        private

        def new(options)
          Redis.new options
        end

        if ThreeScale::Backend.production?
          def get_options
            {}
          end
        else
          DEFAULT_SERVER = '127.0.0.1:22121'.freeze
          private_constant :DEFAULT_SERVER

          def get_options
            { default_url: DEFAULT_SERVER }
          end
        end
      end
    end
  end
end
