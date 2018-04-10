require 'rack'
require '3scale/backend/cors'

module ThreeScale
  module Backend
    module Rack
      class ExceptionCatcher
        # These are the headers responded with when an error happens,
        # and here we include the CORS ones.
        # Note that this way of managing the errors is fundamentally
        # broken, as important information gets lost. That is the case
        # with response headers and other processing that has happened
        # until an exception was raised.
        # A refactoring to use Sinatra's error facilities is in order.
        ERROR_HEADERS = {
          'Content-Type'.freeze => 'application/vnd.3scale-v2.0+xml'.freeze,
        }.merge(Backend::CORS.const_get(:HEADERS)).freeze
        private_constant :ERROR_HEADERS

        INVALID_BYTE_SEQUENCE_ERR_MSG = 'Invalid query parameters: '\
          'invalid byte sequence in UTF-8'.freeze
        private_constant :INVALID_BYTE_SEQUENCE_ERR_MSG

        INVALID_PERCENT_ENCODING_ERR_MSG = 'Invalid query parameters: '\
        'invalid %-encoding'.freeze
        private_constant :INVALID_PERCENT_ENCODING_ERR_MSG

        # Raised with invalid hash params such as:
        # usage[]=1&usage[metric]=1.
        # This is not the whole message. It contains the affected param at the end.
        EXPECTED_HASH_ERR_MSG = 'Invalid query parameters: '\
          'expected Hash (got Array)'.freeze
        private_constant :EXPECTED_HASH_ERR_MSG

        def initialize(app)
          @app = app
        end

        def call(env)
          resp = @app.call(env)
          filter_encoding_error_response resp, env
        rescue Backend::Error => e
          delete_sinatra_error! env
          respond_with e.http_code, prepare_body(e.to_xml, env)
        rescue Exception => e
          unhandled_exception(e)
        end

        private

        # raise up the chain an unhandled exception - but test first for an edge
        # case with Rack key space limit for parsing requests.
        # See https://github.com/rack/rack/blob/2.0.4/lib/rack/query_parser.rb#L166
        def unhandled_exception(e)
          if e.class == RangeError &&
              e.message == 'exceeded available parameter key space'.freeze
            respond_with 400, Backend::NotValidData.new.to_xml
          else
            raise e
          end
        end

        # Private: Deletes 'sinatra.error' key in Rack's env hash.
        # Some external services report 'sinatra.error' and we don't want it when
        # the error is rescued and managed by us with the error handler.
        #
        # env - The environment Hash.
        #
        # Returns nothing.
        def delete_sinatra_error!(env)
          env['sinatra.error'.freeze] = nil
        end

        # Private: Prepares the body to include in the reponse.
        #
        # body - Proposed body String.
        # env - The environment Hash.
        #
        # Returns String.
        def prepare_body(body, env)
          Backend::Listener.threescale_extensions(env)[:no_body] ? ''.freeze : body
        end

        # Returns Rack response.
        #   Format https://rack.github.io/
        #   Array with three elements:
        #   *) The HTTP response code
        #   *) A Hash of headers
        #   *) The response body, which must respond to `each`
        def respond_with(code, body)
          [code, ERROR_HEADERS.dup, [body]]
        end

        # Private:
        # Filter to transform response under specific conditions:
        #   - http_status is 400 and error code refers to encoding issues.
        #   - http_status is 400 and error code refers to a malformed hash param.
        # When input request has one of those issues, Sinatra does not raise error
        # and it prepares its own response. For backwards compatibility, we need
        # to capture the error and customize response accordingly.
        # Best and cleanest way to accomplish this is using error handlers. However,
        # Sinatra 2.0.0 has a bug when registering error handlers and request has encoding issues.
        # It has been reported in https://github.com/sinatra/sinatra/issues/1350
        #
        # resp - Rack response. Format https://rack.github.io/
        #         Array with three elements:
        #         *) The HTTP response code
        #         *) A Hash of headers
        #         *) The response body, which must respond to `each`
        #
        # env - The environment Hash.
        #
        # Returns Rack response.
        def filter_encoding_error_response(resp, env)
          return resp unless resp.first == 400
          # According to http://www.rubydoc.info/github/rack/rack/master/file/SPEC#The_Body
          # The Body must respond to each and must only yield String values.
          resp_body = resp.last.inject('') { |acc, x| acc << x }

          if resp_body == INVALID_BYTE_SEQUENCE_ERR_MSG
            delete_sinatra_error! env
            resp = respond_with 400, Backend::NotValidData.new.to_xml
          elsif resp_body.start_with?(EXPECTED_HASH_ERR_MSG)
            delete_sinatra_error! env
            resp = respond_with 400, Backend::BadRequest.new.to_xml
          elsif resp_body.start_with?(INVALID_PERCENT_ENCODING_ERR_MSG)
            delete_sinatra_error! env
            resp = respond_with 400, Backend::BadRequest.new(INVALID_PERCENT_ENCODING_ERR_MSG).to_xml
          end

          resp
        end
      end
    end
  end
end
