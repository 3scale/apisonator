module ThreeScale
  module Backend
    class Listener < Sinatra::Base
      disable :logging
      disable :raise_errors
      disable :show_exceptions
      
      ## ------------ DOCS --------------
      ##~ sapi = source2swagger.namespace("Service Management API")
      ##~ sapi.basePath = "http://su1.3scale.net"
      ##~ sapi.swagrVersion = "0.1a"
      ##~ sapi.apiVersion = "1.0"
      ##
      ## ------------ DOCS COMMON -------
      ##~ @parameter_provider_key = {"name" => "provider_key", "dataType" => "string", "required" => true, "paramType" => "query"}
      ##~ @parameter_provider_key["description"] = "Provider key."
      ##~ @parameter_provider_key["threescale_name"] = "api_key"
      ##
      ##~ @parameter_service_id = {"name" => "service_id", "dataType" => "string", "required" => false, "paramType" => "query"}
      ##~ @parameter_service_id["description"] = "Service id. Required only if you have more than one service."
      ##~ @parameter_service_id["threescale_name"] = "service_id"
      ##
      ##~ @parameter_app_id = {"name" => "app_id", "dataType" => "string", "required" => true, "paramType" => "query"}
      ##~ @parameter_app_id["description"] = "Application Id (in the case of app_id/app_key authentication mode)"
      ##~ @parameter_app_id["threescale_name"] = "app_id"
      ##
      ##~ @parameter_client_id = {"name" => "app_id", "dataType" => "string", "required" => true, "paramType" => "query"}
      ##~ @parameter_client_id["description"] = "Client Id (in the case of oauth authentication mode, client_id == app_id)"
      ##~ @parameter_client_id["threescale_name"] = "app_id"      
      ##
      ##~ @parameter_app_key = {"name" => "app_key", "dataType" => "string", "required" => false, "paramType" => "query"}
      ##~ @parameter_app_key["description"] = "Application Key (in the case of app_id/app_key authentication mode). App key is required if the application has at least on app key."
      ##~ @parameter_app_key["threescale_name"] = "app_key"
      
      ##~ @parameter_user_key = {"name" => "user_key", "dataType" => "string", "required" => true, "paramType" => "query"}
      ##~ @parameter_user_key["description"] = "User Key (in the case of user_key authentication mode)."
      ##~ @parameter_user_key["threescale_name"] = "user_key" 
      ##  FIXME: THIS IS GOING TO BE A PROBLEM
      
      ##~ @parameter_user_id = {"name" => "user_id", "dataType" => "string", "required" => false, "paramType" => "query"}
      ##~ @parameter_user_id["description"] = "User id. String identifying a end user. Required only when the application is rate limiting end users. The End User plans feature is not available in all 3scale plans."
      
      ##~ @parameter_referrer = {"name" => "referrer", "dataType" => "string", "required" => false, "paramType" => "query"}
      ##~ @parameter_referrer["description"] = "Referrer IP Address or Domain. Required only if referrer filtering is enabled. If special value '*' (wildcard) is passed, the referrer check is bypassed."
      
      ##  FIXME: CHECK THIS ONE TOO
      ##~ @parameter_no_body = {"name" => "no_body", "dataType" => "boolean", "required" => false, "paramType" => "query"}
      ##~ @parameter_no_body["description"] = "If no_body is passed the response will not include HTTP body."
      
      ##~ @parameter_usage = {"name" => "usage", "dataType" => "hash", "required" => false, "paramType" => "query", "allowMultiple" => true}
      ##~ @parameter_usage["description"] = "Usage"
      ##
      ##~ @parameter_usage_fields = {"name" => "metric", "dataType" => "custom", "required" => true, "paramType" => "query"}
      ##~ @parameter_usage_fields["description"] = "Metric to be reported"
      ##~ @parameter_usage_fields["threescale_name"] = "metric"
      ##
      ##~ @parameter_usage["parameters"] = [] 
      ##~ @parameter_usage["parameters"] << @parameter_usage_fields
      
      ##~ @parameter_transaction = {"name" => "transactions", "dataType" => "array", "required" => true, "paramType" => "body", "allowMultiple" => true}
      ##~ @parameter_transaction["description"] = "Transactions to be reported"
      ##~ @parameter_transaction["parameters"] = [] 
      
      ##~ @parameter_transaction["parameters"] << @parameter_app_id
      ##~ @timestamp = {"name" => "timestamp", "dataType" => "string", "required" => false, "paramType" => "body"}
      ##~ @timestamp["description"] = "timestamp"
      ##~ @parameter_transaction["parameters"] << @timestamp
      ##~ @parameter_transaction["parameters"] << @parameter_usage
      
       
      ## ------------ DOCS --------------

      configure :production do
        disable :dump_errors
      end

      set :views, File.dirname(__FILE__) + '/views'

      register AllowMethods

      use Rack::RestApiVersioning, :default_version => '2.0'

      before do
        content_type 'application/vnd.3scale-v2.0+xml'
      end

      ## ------------ DOCS --------------
      ##~ sapi = source2swagger.namespace("Service Management API")
      ##~ a = sapi.apis.add 
      ##~ a.set "path" => "/transactions.xml", "format" => "xml"
      ##~ op = a.operations.add     
      ##~ op.set :httpMethod => "POST", :tags => ["report","app_id"], :nickname => "report_nickname", :deprecated => false
      ##~ op.summary = "Report for app_id/app_key authentication mode"
      ##~ op.description = "Report the transactions to 3scale backend. This operation typically updates the metrics passed in the usage parameters. You can send up to 1K transactions in a single POST request. Transactions are processed asynchronously by the 3scale's backend."
      
      ##~ op.parameters.add @parameter_provider_key
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_transaction
      
            
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


      ## ------------ DOCS --------------
      ##~ sapi = source2swagger.namespace("Service Management API")
      ##~ a = sapi.apis.add 
      ##~ a.set "path" => "/transactions/authorize.xml", "format" => "xml"
      ##~ op = a.operations.add     
      ##~ op.set :httpMethod => "GET", :tags => ["authorize","app_id"], :nickname => "authorize_app_id", :deprecated => false
      ##~ op.summary = "Authorize summary for app_id/app_key authentication mode"
      ##~ op.description = "Authorize operation for the app_id/app_key authentication mode. This operation is read only, the usage of the metrics need to be updated with the /transactions.xml call."
      ##~ op.parameters.add @parameter_provider_key
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_app_id
      ##~ op.parameters.add @parameter_app_key
      ##~ op.parameters.add @parameter_referrer
      ##~ op.parameters.add @parameter_user_id
      ##~ op.parameters.add @parameter_usage
      ##~ op.parameters.add @parameter_no_body
      ## 
      ##~ a = sapi.apis.add 
      ##~ a.set "path" => "/transactions/authorize.xml", "format" => "xml"
      ##~ op = a.operations.add
      ##~ op.set :httpMethod => "GET", :tags => ["authorize","user_key"], :nickname => "authorize_user_key", :deprecated => false
      ##~ op.summary = "Authorize summary for user_key authentication mode"
      ##~ op.description = "Authorize operation for the user_key authentication mode. This operation is read only, the usage of the metrics need to be updated with the /transactions.xml call."      
      ##~ op.parameters.add @parameter_provider_key
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_user_key
      ##~ op.parameters.add @parameter_referrer
      ##~ op.parameters.add @parameter_user_id
      ##~ op.parameters.add @parameter_usage
      ##~ op.parameters.add @parameter_no_body
      ##

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

      ## ------------ DOCS --------------
      ##~ sapi = source2swagger.namespace("Service Management API")
      ##~ a = sapi.apis.add 
      ##~ a.set "path" => "/transactions/oauth_authorize.xml", "format" => "xml"
      ##~ op = a.operations.add     
      ##~ op.set :httpMethod => "GET", :tags => ["authorize","user_key"], :nickname => "oauth_authorize", :deprecated => false
      ##~ op.summary = "Authorize summary for oauth authentication mode"
      ##~ a.description = "Authorize operation for the oauth authentication mode. This operation is read only, the usage of the metrics need to be updated with the /transactions.xml call."      
      ##~ op.parameters.add @parameter_provider_key
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_client_id
      ##~ op.parameters.add @parameter_referrer
      ##~ op.parameters.add @parameter_user_id
      ##~ op.parameters.add @parameter_usage
      ##~ op.parameters.add @parameter_no_body

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

      ## ------------ DOCS --------------
      ##~ sapi = source2swagger.namespace("Service Management API")
      ##~ a = sapi.apis.add 
      ##~ a.set "path" => "/transactions/authrep.xml", "format" => "xml"
      ##~ op = a.operations.add     
      ##~ op.set :httpMethod => "GET", :tags => ["authrep","app_id"], :nickname => "authrep_app_id", :deprecated => false
      ##~ op.summary = "Authrep summary for app_id/app_key authentication mode"
      ##~ op.description = "Authorize+Report operation for the app_id/app_key authentication mode. This operation updates the metrics with the values passed on the usage parameter, it basically does the authorize (/transactions/authorize.xml) and the report calls (/transactions.xml) in a single shot."
      ##~ op.parameters.add @parameter_provider_key
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_app_id
      ##~ op.parameters.add @parameter_app_key
      ##~ op.parameters.add @parameter_referrer
      ##~ op.parameters.add @parameter_user_id
      ##~ op.parameters.add @parameter_usage
      ##~ op.parameters.add @parameter_no_body
      ## 
      ##~ a = sapi.apis.add 
      ##~ a.set "path" => "/transactions/authrep.xml", "format" => "xml"
      ##~ op = a.operations.add     
      ##~ op.set :httpMethod => "GET", :tags => ["authrep","user_key"], :nickname => "authrep_user_key", :deprecated => false
      ##~ op.summary = "Authrep summary for user_key authentication mode"
      ##~ op.description = "Authorize+Report operation for the user_key authentication mode. This operation updates the metrics with the values passed on the usage parameter, it basically does the authorize (/transactions/authorize.xml) and the report calls (/transactions.xml) in a single shot."
      ##~ op.parameters.add @parameter_provider_key
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_user_key
      ##~ op.parameters.add @parameter_referrer
      ##~ op.parameters.add @parameter_user_id
      ##~ op.parameters.add @parameter_usage
      ##~ op.parameters.add @parameter_no_body
      ##

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

      get '/applications/:app_id/log_requests.xml' do
        ## FIXME: two ways of doing the same
        ## get '/services/:service_id/applications/:app_id/log_requests.xml'
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

      delete '/applications/:app_id/log_requests.xml' do
        ## FIXME: two ways of doing the same
        ## delete '/services/:service_id/applications/:app_id/log_requests.xml'
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
