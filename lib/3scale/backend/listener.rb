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
        ## return error code 400 (Bad request) if the parameters are not there
        ## I put 403 (Forbidden) for consitency however it should be 400 
        ## reg = /^([^:\/#?& @%+;=$,<>~\^`\[\]{}\| "]|%[A-F0-9]{2})*$/

        if params.nil? || params[:provider_key].nil? || params[:provider_key].empty? || params[:transactions].nil? || params[:transactions].is_a?(Array)
          empty_response 403
          return
        end

        Transactor.report(params[:provider_key], params[:service_id], params[:transactions])
        empty_response 202
      end


      get '/transactions/authorize.xml' do
        if params.nil? || params[:provider_key].nil? || params[:provider_key].empty? || !(params[:usage].nil? || params[:usage].is_a?(Hash))
          empty_response 403
          return
        end
        
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
        if params.nil? || params[:provider_key].nil? || params[:provider_key].empty? || !(params[:usage].nil? || params[:usage].is_a?(Hash))
          empty_response 403
          return
        end

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
        if params.nil? || params[:provider_key].nil? || params[:provider_key].empty? || !(params[:usage].nil? || params[:usage].is_a?(Hash))
          empty_response 403
          return
        end

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

      ## TRANSACTIONS & ERRORS

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

      ## LOG REQUESTS

      get '/services/:service_id/applications/:app_id/log_requests.xml' do
        @list = LogRequestStorage.list_by_application(service_id, application.id)
        builder :log_requests
      end

      get '/services/:service_id/log_requests.xml' do
        @list = LogRequestStorage.list_by_service(service_id)
        builder :log_requests
      end

      get '/services/:service_id/applications/:app_id/log_requests/count.xml' do
        @count = LogRequestStorage.count_by_application(service_id, application.id)
        builder :log_requests_count
      end

      get '/services/:service_id/log_requests/count.xml' do
        @count = LogRequestStorage.count_by_service(service_id)
        builder :log_requests_count
      end

      delete '/services/:service_id/applications/:app_id/log_requests.xml' do
        LogRequestStorage.delete_by_application(service_id, application.id)
        empty_response
      end

      delete '/services/:service_id/log_requests.xml' do
        LogRequestStorage.delete_by_service(service_id)
        empty_response
      end

      ## ALERTS & VIOLATIONS

      get '/services/:service_id/alerts.xml' do  
        @list = Transactor.latest_alerts(service_id)
        builder :latest_alerts
      end

      get '/services/:service_id/alert_limits.xml' do
        @list = Transactor.alert_limit(service_id)
        builder :alert_limits
      end

      post '/services/:service_id/alert_limits/:limit.xml' do
        @list = Transactor.add_alert_limit(service_id, params[:limit])
        builder :alert_limits
      end

      delete '/services/:service_id/alert_limits/:limit.xml' do
        @list = Transactor.delete_alert_limit(service_id, params[:limit])
        builder :alert_limits
      end

      get "/services/:service_id/applications/:app_id/utilization.xml" do
        @usage_reports, @max_record, @max_utilization, @stats = Transactor.utilization(service_id, application.id)
        builder :utilization
      end
      
      get '/applications/:app_id/keys.xml' do
        @keys = application.keys
        builder :application_keys
      end

      get '/applications/:app_id/utilization.xml' do
        ## FIXME: two ways of doing the same
        ## "/services/:service_id/applications/:app_id/utilization.xml"
        @usage_reports, @max_record, @max_utilization, @stats = Transactor.utilization(service_id, application.id)
        builder :utilization
      end

      post '/applications/:app_id/keys.xml' do

        if params[:key].nil? || params[:key].empty?
          @key = application.create_key
        else
          @key = application.create_key(params[:key])
        end

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
        when ThreeScale::Core::Error
          error_code = 405
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
        @application ||= Application.load_by_id_or_user_key!(service_id, params[:app_id], params[:user_key])
      end

      # FIXME: this operations can be done more efficiently, without loading the whole service
      def service_id
        if params[:service_id].nil? || params[:service_id].empty?
          @service_id ||= Service.load_id!(params[:provider_key])
        else
          service = Service.load_by_id(params[:service_id]) 
          raise ProviderKeyInvalid, params[:provider_key] if service.nil? || service.provider_key!=params[:provider_key]
          @service_id ||= params[:service_id]
        end
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
