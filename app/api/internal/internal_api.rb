module ThreeScale
  module Backend
    class InternalAPI < API

      before do
        content_type 'application/json'
        parse_json_params params
        massage_params params
      end

      get '/check' do
        {status: :ok}.to_json
      end

      private

      def parse_json_params(params)
        json_params = {}
        params.each do |key, value|
          if value.nil?
            json_params.merge! JSON.parse(key)
            params.delete key
          end
        end
        params.merge! json_params
      end

      def filter_params(params)
        params.reject!{ |k, v| !ACCEPTED_PARAMS.include? k }
      end

      # Symbolizes keys.
      def massage_params(params)
        params.keys.each do |key|
          unless key.is_a? Symbol
            params[key.to_sym] = params[key]
            params.delete key
            key = key.to_sym
          end

          if params[key].is_a? Hash
            massage_params params[key]
          end
        end
      end

      def respond_with_400(exception)
        status 400
        {error: exception.message}.to_json
      end
    end
  end
end

require_relative 'services_api'
