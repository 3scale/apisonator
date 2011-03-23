module ThreeScale
  module Backend
    class Listener < Sinatra::Base
      disable :logging
      disable :raise_errors
      disable :show_exceptions

      configure :production do
        disable :dump_errors
      end

      set :views, File.dirname(__FILE__) + '/views'

      register AllowMethods

      use Rack::RestApiVersioning, :default_version => '2.0'

      before do
        content_type 'application/vnd.3scale-v2.0+xml'
      end

      post '/transactions.xml' do
        Transactor.report(params[:provider_key], params[:transactions])
        empty_response 202
      end


      get '/transactions/authorize.xml' do

				authorization, cached_authorization_text, cached_authorization_result = Transactor.authorize(params[:provider_key], params)
        
        if cached_authorization_text.nil? || cached_authorization_result.nil?
    			response_code = if authorization.authorized?
		                        200
		                      else
		                        409
		                      end
		      status response_code
		      if params[:no_body]
		        body nil
		      else
						body authorization.to_xml
		      end
				else

					response_code = if cached_authorization_result
														200
													else
														409
													end
					status response_code
					if params[:no_body]
						body nil
					else
						body cached_authorization_text
					end
				end

      end

      get '/transactions/oauth_authorize.xml' do

        authorization, cached_authorization_text, cached_authorization_result = Transactor.oauth_authorize(params[:provider_key], params)

        if cached_authorization_text.nil? || cached_authorization_result.nil?
    			response_code = if authorization.authorized?
		                        200
		                      else
		                        409
		                      end
		      status response_code
		      if params[:no_body]
		        body nil
		      else
						body authorization.to_xml(:oauth => true)
		      end
				else

					response_code = if cached_authorization_result
														200
													else
														409
													end
					status response_code
					if params[:no_body]
						body nil
					else
						body cached_authorization_text
					end
				end
      end

      get '/transactions/authrep.xml' do
        authorization, cached_authorization_text, cached_authorization_result = Transactor.authrep(params[:provider_key], params)

				if cached_authorization_text.nil? || cached_authorization_result.nil?
    			response_code = if authorization.authorized?
		                        200
		                      else
		                        409
		                      end
		      status response_code
		      if params[:no_body]
		        body nil
		      else
						body authorization.to_xml(:usage => params[:usage])
		      end
				else

					response_code = if cached_authorization_result
														200
													else
														409
													end
					status response_code
					if params[:no_body]
						body nil
					else
						body cached_authorization_text
					end
				end

				
      end

      get '/transactions/errors.xml' do
        @errors = ErrorStorage.list(service_id, :page     => params[:page],
                                                :per_page => params[:per_page])

        builder :transaction_errors
      end

      delete '/transactions/errors.xml' do
        ErrorStorage.delete_all(service_id)
        empty_response
      end

      get '/transactions/errors/count.xml' do
        @count = ErrorStorage.count(service_id)

        builder :transaction_error_count
      end

      get '/transactions/latest.xml' do
        @transactions = TransactionStorage.list(service_id)

        builder :latest_transactions
      end

      get '/applications/:app_id/keys.xml' do
        @keys = application.keys

        builder :application_keys
      end

      post '/applications/:app_id/keys.xml' do
        @key = application.create_key

        headers 'Location' => application_resource_url(application, :keys, @key)
        status 201
        builder :create_application_key
      end

      delete '/applications/:app_id/keys/:key.xml' do
        application.delete_key(params[:key])
        empty_response
      end

      get '/applications/:app_id/referrer_filters.xml' do
        @referrer_filters = application.referrer_filters

        builder :application_referrer_filters
      end

      post '/applications/:app_id/referrer_filters.xml' do
        @referrer_filter = application.create_referrer_filter(params[:referrer_filter])

        headers 'Location' => application_resource_url(application, :referrer_filters, @referrer_filter)
        status 201
        builder :create_application_referrer_filter
      end

      delete '/applications/:app_id/referrer_filters/:id.xml' do
        application.delete_referrer_filter(params[:id])
        empty_response
      end

      get '/check.txt' do
        content_type 'text/plain'
        body 'ok'
      end

      error do
        error_code = 0
        case exception = env['sinatra.error']
        when ThreeScale::Backend::Invalid
          error_code = 422
        when ThreeScale::Backend::NotFound
          error_code = 404
        when ThreeScale::Backend::Error
          error_code = 403
        else
          raise exception
        end
        if params[:no_body]
          error error_code, ""
        else
          error error_code, exception.to_xml
        end
      end

      error Sinatra::NotFound do
        error 404, ""
      end

      private

      def application
        @application ||= Application.load!(service_id, params[:app_id])
      end

      def service_id
        @service_id ||= Service.load_id!(params[:provider_key])
      end

      def application_resource_url(application, type, value)
        url("/applications/#{application.id}/#{type}/#{value}.xml")
      end

      def url(path)
        protocol = request.env['HTTPS'] == 'on' ? 'https' : 'http'
        server   = request.env['SERVER_NAME']

        url = "#{protocol}://#{server}#{path}"
        url += "?provider_key=#{params[:provider_key]}" if params[:provider_key]
        url
      end

      def empty_response(code = 200)
        status code
        body nil
      end
    end
  end
end
