module ThreeScale
  module Backend
    class Endpoint < Sinatra::Base
      set :environment, :production
      disable :logging
      disable :dump_errors

          
      use Rack::RestApiVersioning, :default_version => '2.0'

      before do
        content_type 'application/vnd.3scale-v2.0+xml'
      end

      register AllowMethods
      allow_methods '/transactions.xml',                   :post
      allow_methods '/transactions/authorize.xml',         :get
      allow_methods '/applications/:app_id/keys.xml',      :get, :post
      allow_methods '/applications/:app_id/keys/:key.xml', :delete

      get '/check.txt' do
        content_type 'text/plain'
      end

      post '/transactions.xml' do
        Transactor.report(params[:provider_key], params[:transactions])

        status 202
      end
      
      get '/transactions/authorize.xml' do
        authorization = Transactor.authorize(params[:provider_key],
                                             params[:app_id],
                                             params[:app_key])
        
        status 200
        authorization.to_xml
      end

      get '/applications/:app_id/keys.xml' do
        status 200

        builder do |xml|
          xml.instruct!
          xml.keys do
            application.keys.sort.each do |key|
              xml.key :value => key, :href => application_key_url(application, key)
            end
          end
        end
      end
      
      post '/applications/:app_id/keys.xml' do
        key = application.create_key!
        url = application_key_url(application, key)

        headers 'Location' => url
        status 201

        builder do |xml|
          xml.instruct!
          xml.key :value => key, :href => url 
        end
      end
      
      delete '/applications/:app_id/keys/:key.xml' do
        application.delete_key!(params[:key])

        status 200
      end

      error do
        case exception = env['sinatra.error']
        when ThreeScale::Backend::NotFound
          error 404, exception.to_xml
        when ThreeScale::Backend::Error
          error 403, exception.to_xml
        else
          raise exception
        end
      end

      private

      def application
        @application ||= Application.load!(service_id, params[:app_id])
      end

      def service_id
        @service_id ||= Service.load_id!(params[:provider_key])
      end

      def application_key_url(application, key)
        url("/applications/#{application.id}/keys/#{key}.xml")
      end

      def url(path)
        protocol = request.env['HTTPS'] == 'on' ? 'https' : 'http'
        server   = request.env['SERVER_NAME']

        url = "#{protocol}://#{server}#{path}"
        url += "?provider_key=#{params[:provider_key]}" if params[:provider_key]
        url
      end
    end
  end
end
