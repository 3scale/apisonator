require '3scale/backend/version'
require 'sinatra/namespace'
require 'json'

module ThreeScale
  module Backend
    module API
      def self.internal_api(ns, &blk)
        Internal.class_eval { namespace ns, &blk }
      end

      class Internal < Sinatra::Base

        def initialize(username: nil, password: nil)
          @username = username
          @password = password
          @credentials_set = credentials_set?(username, password)
          super()
        end

        register Sinatra::Namespace

        # using a class variable instead of settings because we want this to be
        # as fast as possible when responding, since we hit /status a lot.
        @@status = { status: :ok,
                     version: { backend: ThreeScale::Backend::VERSION } }.to_json

        class << self
          # the method below is used by the Rack application for auth
          def check_password(username, password)
            if @credentials_set
              username == @username && password == @password
            else
              true
            end
          end
        end

        before do
          content_type 'application/json'
          parse_json_params params
        end

        error Sinatra::NotFound do
          { status: :not_found, error: 'Not found'}.to_json
        end

        get '/check.json' do
          {status: :ok}.to_json
        end

        get '/status' do
          @@status
        end

        def self.define_private_endpoints?
          ThreeScale::Backend.test? || ThreeScale::Backend.development?
        end

        private

        def credentials_set?(username, password)
          (!username.nil? && !username.empty?) ||
              (!password.nil? && !password.empty?)
        end

        def parse_json_params(params)
          body = request.body.read
          params.merge! JSON.parse(body, symbolize_names: true) unless body.empty?
        end

        def filter_params(params)
          params.reject!{ |k, v| !ACCEPTED_PARAMS.include? k }
        end

        def respond_with_400(exception)
          halt 400, {error: exception.message}.to_json
        end

        def respond_with_404(message)
          halt 404, {status: :not_found, error: message}.to_json
        end

      end
    end
  end
end

