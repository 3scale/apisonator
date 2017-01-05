require 'rack'

module Rack
  class RackExceptionCatcher
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
      ThreeScale::Backend::Listener.threescale_extensions(env)[:no_body] ? '' : body
    end

    def respond_with(code, body)
      [code, { 'Content-Type' => 'application/vnd.3scale-v2.0+xml' }, [body]]
    end
  end

  module RequestExceptionExtensions
  end
end

Rack::Request.send(:include, Rack::RequestExceptionExtensions)