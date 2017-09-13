require 'rack'
require '3scale/backend/cors'

module Rack
  class RackExceptionCatcher

    # These are the headers responded with when an error happens,
    # and here we include the CORS ones.
    # Note that this way of managing the errors is fundamentally
    # broken, as important information gets lost. That is the case
    # with response headers and other processing that has happened
    # until an exception was raised.
    # A refactoring to use Sinatra's error facilities is in order.
    ERROR_HEADERS = {
      'Content-Type'.freeze => 'application/vnd.3scale-v2.0+xml'.freeze,
    }.merge(ThreeScale::Backend::CORS.const_get(:HEADERS)).freeze
    private_constant :ERROR_HEADERS

    def initialize(app, options = {})
      @app = app
      @options = options
    end

    def call(env)
      @app.call(env)
    rescue ThreeScale::Backend::Error => e
      delete_sinatra_error! env
      respond_with e.http_code, prepare_body(e.to_xml, env)
    rescue TypeError
      respond_with 400, prepare_body(ThreeScale::Backend::BadRequest.new.to_xml, env)
    rescue Rack::Utils::InvalidParameterError
      delete_sinatra_error! env
      respond_with 400, ThreeScale::Backend::NotValidData.new.to_xml
    rescue Exception => e
      if e.class == RangeError && e.message == "exceeded available parameter key space"
        respond_with 400, ThreeScale::Backend::NotValidData.new.to_xml
      else
        raise e
      end
    end

    private

    # Private: Deletes 'sinatra.error' key in Rack's env hash.
    # Newer version of airbrake gem is reporting 'sinatra.error' and we don't
    # want it when the error is rescued and managed by us with the error handler.
    #
    # env - The environment Hash.
    #
    # Returns nothing.
    def delete_sinatra_error!(env)
      env['sinatra.error'.freeze] = nil
    end

    # Private: Prepares the body to inlude in the reponse.
    #
    # body - Proposed body String.
    # env - The environment Hash.
    #
    # Returns String.
    def prepare_body(body, env)
      ThreeScale::Backend::Listener.threescale_extensions(env)[:no_body] ? ''.freeze : body
    end

    def respond_with(code, body)
      [code, ERROR_HEADERS.dup, [body]]
    end
  end
end
