require 'rack'

module Rack
  class RackExceptionCatcher
    def initialize(app, options = {})
      @app = app
      @options = options
    end

    def call(env)
      @app.call(env)
    rescue TypeError => e
        respond_with 400, prepare_body(ThreeScale::Backend::BadRequest.new.to_xml, env)
    rescue ThreeScale::Backend::Invalid => e
      delete_sinatra_error! env
      respond_with 422, prepare_body(e.to_xml, env)
    rescue ThreeScale::Backend::NotFound => e
      delete_sinatra_error! env
      respond_with 404, prepare_body(e.to_xml, env)
    rescue ThreeScale::Backend::Error => e
      delete_sinatra_error! env
      respond_with 403, prepare_body(e.to_xml, env)
    rescue ThreeScale::Core::Error => e
      delete_sinatra_error! env
      respond_with 405, prepare_body(e.to_xml, env)
    rescue Sinatra::NotFound => e
      delete_sinatra_error! env
      respond_with 404, ''
    rescue Exception => e
      if e.class == ArgumentError && (
          e.message == "invalid byte sequence in UTF-8" ||
          e.message =~ /invalid .-encoding/
        )
        delete_sinatra_error! env
        respond_with 400, ThreeScale::Backend::NotValidData.new.to_xml
      elsif e.class == RangeError && e.message == "exceeded available parameter key space"
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
      env['sinatra.error'] = nil
    end

    # Private: Prepares the body to inlude in the reponse.
    #
    # body - Proposed body String.
    # env - The environment Hash.
    #
    # Returns String.
    def prepare_body(body, env)
      env['rack.request.query_hash']['no_body'] == 'true' ? '' : body
    end

    def respond_with(code, body)
      [code, { 'Content-Type' => 'application/vnd.3scale-v2.0+xml' }, [ body ]]
    end
  end

  module RequestExceptionExtensions
  end
end

Rack::Request.send(:include, Rack::RequestExceptionExtensions)