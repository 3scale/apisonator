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
          [400, { 'Content-Type' => 'application/vnd.3scale-v2.0+xml' }, [ ThreeScale::Backend::NotValidData.new().to_xml ]]
        elsif e.class == ArgumentError && e.message =~ /invalid .-encoding/
          [400, { 'Content-Type' => 'application/vnd.3scale-v2.0+xml' }, [ ThreeScale::Backend::NotValidData.new().to_xml ]] 
        elsif e.class == RangeError && e.message == "exceeded available parameter key space"
          [400, { 'Content-Type' => 'application/vnd.3scale-v2.0+xml' }, [ ThreeScale::Backend::NotValidData.new().to_xml ]] 
        else
          ## temporal monitor
          begin
            f = ::File.new("/mnt/tmp_rack_weird_exceptions.log","a")
            f.puts "------"
            f.puts Time.now.utc.to_s
            f.puts env.inspect
            f.puts e
            f.close
          rescue Exception => exc
          end  
          raise e
        end
      end
    end
  end

  module RequestExceptionExtensions
  end
end

Rack::Request.send(:include, Rack::RequestExceptionExtensions)