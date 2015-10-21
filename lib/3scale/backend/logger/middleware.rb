module ThreeScale
  module Backend
    class Logger
      class Middleware
        Z3_RANGE = 0..3.freeze

        private_constant(*[
          :HTTP_X_FORWARDED_FOR,
          :REMOTE_ADDR,
          :REMOTE_USER,
          :REQUEST_METHOD,
          :PATH_INFO,
          :HTTP_VERSION,
          :HTTP_X_REQUEST_ID,
          :QUERY_STRING
        ].each do |k|
          const_set(k, k.to_s.freeze)
        end)

        private_constant(*{
          FORMAT: "%s - %s [%s] \"%s %s%s %s\" %d %s %s %s %s %s %s %s %s %s\n",
          ERROR_FORMAT: "%s - %s [%s] \"%s %s%s %s\" %d \"%s\" %s %s\n",
          DATE_FORMAT: '%d/%b/%Y %H:%M:%S %Z',
          STR_PROVIDER_KEY: 'provider_key',
          STR_POST: 'POST',
          STR_EQUAL: '=',
          STR_DASH: '-',
          STR_AMPERSAND: '&',
          STR_ZERO: '0',
          STR_RACK_ERRORS: 'rack.errors',
          STR_EMPTY: '',
          STR_QUESTION_MARK: '?',
          STR_NEWLINE: "\n",
          STR_CONTENT_LENGTH: 'Content-Length'
        }.map do |k, v|
          const_set(k, v.freeze)
          k
        end)

        def initialize(app, logger=STDOUT)
          @app = app
          @logger = logger
        end

        def call(env)
          began_at = Time.now
          begin
            status, header, body = @app.call(env)
          rescue Exception => e
            log_error(env, 500, e.message, began_at)
            raise e
          end
          header = Rack::Utils::HeaderHash.new(header)
          body = Rack::BodyProxy.new(body) { log(env, status, header, began_at) }
          [status, header, body]
        end

        private

        def log_error(env, status, error, began_at)
          now = Time.now.getutc
          qs  = extract_query_string(env)

          logger = @logger || env[STR_RACK_ERRORS] || STDERR
          logger.write ERROR_FORMAT % [
            env[HTTP_X_FORWARDED_FOR] || env[REMOTE_ADDR] || STR_DASH,
            env[REMOTE_USER] || STR_DASH,
            now.strftime(DATE_FORMAT),
            env[REQUEST_METHOD],
            env[PATH_INFO],
            qs.empty? ? STR_EMPTY : STR_QUESTION_MARK + qs.tr(STR_NEWLINE, STR_EMPTY),
            env[HTTP_VERSION],
            status.to_s[Z3_RANGE],
            error,
            now - began_at,
            env[HTTP_X_REQUEST_ID]
          ]
        end

        def log(env, status, header, began_at)
          now      = Time.now.getutc
          qs       = extract_query_string(env)
          length   = extract_content_length(header)
          cache    = ThreeScale::Backend::Cache.stats
          memoizer = ThreeScale::Backend::Memoizer.stats

          logger = @logger || env[STR_RACK_ERRORS] || STDERR
          logger.write FORMAT % [
            env[HTTP_X_FORWARDED_FOR] || env[REMOTE_ADDR] || STR_DASH,
            env[REMOTE_USER] || STR_DASH,
            now.strftime(DATE_FORMAT),
            env[REQUEST_METHOD],
            env[PATH_INFO],
            qs.empty? ? STR_EMPTY : STR_QUESTION_MARK + qs.tr(STR_NEWLINE, STR_EMPTY),
            env[HTTP_VERSION],
            status.to_s[Z3_RANGE],
            length,
            now - began_at,
            cache[:last] || STR_DASH,
            cache[:count] || STR_DASH,
            cache[:hits] || STR_DASH,
            memoizer[:size] || STR_DASH,
            memoizer[:count] || STR_DASH,
            memoizer[:hits] || STR_DASH,
            env[HTTP_X_REQUEST_ID]
          ]
        end

        def extract_content_length(headers)
          value = headers[STR_CONTENT_LENGTH] or return STR_DASH
          value.to_s == STR_ZERO ? STR_DASH : value
        end

        def extract_query_string(env)
          oqs = env[QUERY_STRING]
          if env[REQUEST_METHOD].to_s.upcase == STR_POST
            provider_key = Rack::Request.new(env).params[STR_PROVIDER_KEY]
            qs = oqs.dup
            unless provider_key.nil?
              qs << STR_AMPERSAND unless oqs.empty?
              qs << STR_PROVIDER_KEY + STR_EQUAL + provider_key.to_s
            end
          else
            qs = oqs
          end

          qs
        end
      end
    end
  end
end
