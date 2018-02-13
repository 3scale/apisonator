module ThreeScale
  module Backend
    module Logging
      class Middleware
        module Writer
          Z3_RANGE = 0..3.freeze
          private_constant :Z3_RANGE

          private_constant(*[
              :HTTP_X_FORWARDED_FOR,
              :REMOTE_ADDR,
              :REMOTE_USER,
              :REQUEST_METHOD,
              :PATH_INFO,
              :HTTP_VERSION,
              :HTTP_X_REQUEST_ID,
              :QUERY_STRING,
              :HTTP_3SCALE_OPTIONS
          ].each do |k|
            const_set(k, k.to_s.freeze)
          end)

          private_constant(*{
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
              STR_DQUOTE: '"',
              STR_ESCAPED_DQUOTE: '\"',
              STR_CONTENT_LENGTH: 'Content-Length'
          }.map do |k, v|
            const_set(k, v.freeze)
            k
          end)

          def initialize(logger=STDOUT)
            @logger = logger
          end

          def log(env, status, header, began_at)
            data = log_data(env, status, header, began_at)
            log = formatted_log(data)
            logger(env).write(log)
          end

          def log_error(env, status, error, began_at)
            data = log_error_data(env, status, error, began_at)
            error = formatted_error(data)
            logger(env).write(error)
          end

          private

          def logger(env)
            @logger || env[STR_RACK_ERRORS] || STDERR
          end

          def log_data(env, status, header, began_at)
            common_request_data(env, status, began_at)
                .merge(success_specific_data(header))
          end

          def log_error_data(env, status, error, began_at)
            common_request_data(env, status, began_at)
                .merge(error_specific_data(error))
          end

          def common_request_data(env, status, began_at)
            now = Time.now.getutc

            { forwarded_for: env[HTTP_X_FORWARDED_FOR] || env[REMOTE_ADDR] || STR_DASH,
              remote_user: env[REMOTE_USER] || STR_DASH,
              time: now.strftime(DATE_FORMAT),
              method: env[REQUEST_METHOD],
              path_info: env[PATH_INFO],
              query_string: extract_query_string(env),
              http_version: env[HTTP_VERSION],
              status: status.to_s[Z3_RANGE],
              response_time: now - began_at,
              request_id: env[HTTP_X_REQUEST_ID] || STR_DASH,
              extensions: extensions(env) }
          end

          def success_specific_data(header)
            { length: extract_content_length(header) }.merge(memoizer_data)
          end

          def memoizer_data
            memoizer = memoizer_stats

            { memoizer_size: memoizer[:size] || STR_DASH,
              memoizer_count: memoizer[:count] || STR_DASH,
              memoizer_hits: memoizer[:hits] || STR_DASH }
          end

          def error_specific_data(error)
            { error: error }
          end

          def extract_query_string(env)
            qs = env[QUERY_STRING]
            if env[REQUEST_METHOD].to_s.upcase == STR_POST
              provider_key = begin
                ::Rack::Request.new(env).params[STR_PROVIDER_KEY]
              rescue IOError
                # happens when body does not parse
                nil
              end
              unless provider_key.nil?
                qs = qs.dup
                qs << STR_AMPERSAND unless qs.empty?
                qs << STR_PROVIDER_KEY + STR_EQUAL + provider_key.to_s
              end
            end

            qs.empty? ? STR_EMPTY : STR_QUESTION_MARK + qs.tr(STR_NEWLINE, STR_EMPTY)
          end

          def extract_content_length(headers)
            value = headers[STR_CONTENT_LENGTH] or return STR_DASH
            value.to_s == STR_ZERO ? STR_DASH : value
          end

          def extensions(env)
            ext = env[HTTP_3SCALE_OPTIONS]
            ext ? "\"#{ext.gsub(STR_DQUOTE, STR_ESCAPED_DQUOTE)}\"" : STR_DASH
          end

          def memoizer_stats
            ThreeScale::Backend::Memoizer.stats
          end
        end
      end
    end
  end
end
