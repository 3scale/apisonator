module ThreeScale
  module Backend
    class ServicesAPI < InternalAPI
      ACCEPTED_PARAMS = %w(id service provider_key force)

      before do
        content_type 'application/json'
        parse_json_params params
        filter_params params
        massage_params params
      end

      get '/:id' do
        Service.load_by_id(params[:id]).to_json
      end

      post '/' do
        service = Service.save!(params[:service])
        status 201
        {service: service, status: :created}.to_json
      end

      put '/:id' do
        service = Service.load_by_id(params[:id])
        params[:service].each do |attr, value|
          service.send "#{attr}=", value
        end
        service.save!
        {service: service, status: :ok}.to_json
      end

      delete '/:id' do
        begin
          Service.delete_by_id params[:id], force: (params[:force] == 'true')
          {status: :ok}.to_json
        rescue ServiceIsDefaultService => e
          status 400
          {error: e.message}.to_json
        end
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
    end
  end
end
