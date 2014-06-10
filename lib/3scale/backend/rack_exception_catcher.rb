require 'rack'

module Rack
  class RackExceptionCatcher
    def initialize(app, options = {})
      @app = app
      @options = options
    end

    def call(env)
      begin
        @app.call(env)
      rescue Exception => e
        if e.class == TypeError
          [400, { 'Content-Type' => 'application/vnd.3scale-v2.0+xml' }, [ ThreeScale::Backend::BadRequest.new().to_xml ]]
        elsif e.class == ArgumentError && e.message == "invalid byte sequence in UTF-8"
          delete_sinatra_error! env
          [400, { 'Content-Type' => 'application/vnd.3scale-v2.0+xml' }, [ ThreeScale::Backend::NotValidData.new().to_xml ]]
        elsif e.class == ArgumentError && e.message =~ /invalid .-encoding/
          delete_sinatra_error! env
          [400, { 'Content-Type' => 'application/vnd.3scale-v2.0+xml' }, [ ThreeScale::Backend::NotValidData.new().to_xml ]]
        elsif e.class == RangeError && e.message == "exceeded available parameter key space"
          [400, { 'Content-Type' => 'application/vnd.3scale-v2.0+xml' }, [ ThreeScale::Backend::NotValidData.new().to_xml ]]
        else
          raise e
        end
      end
    end

    private

    # Deletes 'sinatra.error' key in Rack's env hash.
    # Newer version of airbrake gem is reporting 'sinatra.error' and we don't
    # want it when the error is rescued and managed by us with the error handler.
    # @return [nil]
    def delete_sinatra_error!(env)
      env['sinatra.error'] = nil
    end
  end

  module RequestExceptionExtensions
  end
end

Rack::Request.send(:include, Rack::RequestExceptionExtensions)