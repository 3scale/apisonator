module ThreeScale
  module Backend
    module API
      internal_api '/service_tokens' do

        head '/:token/:service_id/' do |token, service_id|
          ServiceToken.exists?(token, service_id) ? 200 : 404
        end

        get '/:token/:service_id/provider_key' do |token, service_id|
          if ServiceToken.exists?(token, service_id)
            { status: :found, provider_key: Service.provider_key_for(service_id) }.to_json
          else
            respond_with_404('token/service combination not found'.freeze)
          end
        end

        post '/' do
          check_tokens_param!

          token_pairs = @service_tokens.map do |token, token_info|
            { service_token: token, service_id: token_info[:service_id] }
          end

          begin
            ServiceToken.save_pairs(token_pairs)
            [201, headers, { status: :created }.to_json]
          rescue ServiceToken::ValidationError => e
            halt(e.http_code, { status: :error, error: e.message }.to_json)
          end
        end

        delete '/' do
          check_tokens_param!

          deleted = @service_tokens.count do |token|
            ServiceToken.delete(token[:service_token], token[:service_id]) == 1
          end

          { status: :deleted, count: deleted }.to_json
        end

        private

        def check_tokens_param!
          @service_tokens = params[:service_tokens]
          unless @service_tokens
            halt(400, { error: "missing parameter 'service_tokens'".freeze }.to_json)
          end
        end
      end
    end
  end
end
