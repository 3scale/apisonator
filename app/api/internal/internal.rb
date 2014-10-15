require 'sinatra/namespace'

module ThreeScale
  module Backend
    module API
      def self.internal_api(ns, &blk)
        Internal.class_eval { namespace ns, &blk }
      end

      class Internal < Sinatra::Base
        register Sinatra::Namespace

        before do
          content_type 'application/json'
          parse_json_params params
        end

        get '/check.json' do
          {status: :ok}.to_json
        end

        get '/status' do
          { status: :ok, version: { backend: ThreeScale::Backend::VERSION } }.to_json
        end

        private

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

