require '3scale/backend/version'
require '3scale/backend/cors'
require '3scale/backend/csp'
require 'json'

module ThreeScale
  module Backend
    class Listener < Sinatra::Base
      disable :logging
      enable :raise_errors
      disable :show_exceptions

      include Logging

      ## ------------ DOCS --------------
      ##~ namespace = "Service Management API"
      ##~ sapi = source2swagger.namespace(namespace)
      ##~ sapi.basePath = ""
      ##~ sapi.swaggerVersion = "0.1a"
      ##~ sapi.apiVersion = "1.0"
      ##
      ## ------------ DOCS COMMON -------
      ##~ @parameter_service_token = {"name" => "service_token", "dataType" => "string", "required" => true, "paramType" => "query", "threescale_name" => "service_tokens"}
      ##~ @parameter_service_token["description"] = "Your service api key with 3scale (also known as service token)."
      ##
      ##~ @parameter_service_id = {"name" => "service_id", "dataType" => "string", "required" => true, "paramType" => "query", "threescale_name" => "service_ids"}
      ##~ @parameter_service_id["description"] = "Service id. Required."
      ##
      ##~ @parameter_app_id = {"name" => "app_id", "dataType" => "string", "required" => true, "paramType" => "query", "threescale_name" => "app_ids"}
      ##~ @parameter_app_id["description"] = "App Id (identifier of the application if the auth. pattern is App Id)"
      ##~ @parameter_app_id_inline = @parameter_app_id.clone
      ##~ @parameter_app_id_inline["description_inline"] = true
      ##
      ##~ @parameter_client_id = {"name" => "app_id", "dataType" => "string", "required" => false, "paramType" => "query", "threescale_name" => "app_ids"}
      ##~ @parameter_client_id["description"] = "Client Id (identifier of the application if the auth. pattern is OAuth, note that client_id == app_id)"
      ##~ @parameter_client_id_inline = @parameter_client_id.clone
      ##~ @parameter_client_id_inline["description_inline"] = true

      ##~ @parameter_app_key = {"name" => "app_key", "dataType" => "string", "required" => false, "paramType" => "query", "threescale_name" => "app_keys"}
      ##~ @parameter_app_key["description"] = "App Key (shared secret of the application if the authentication pattern is App Id). The app key is required if the application has one or more keys defined."
      ##
      ##~ @parameter_user_key = {"name" => "user_key", "dataType" => "string", "required" => true, "paramType" => "query", "theescale_name" => "user_keys"}
      ##~ @parameter_user_key["description"] = "User Key (identifier and shared secret of the application if the auth. pattern is Api Key)"
      ##~ @parameter_user_key_inline = @parameter_user_key.clone
      ##~ @parameter_user_key_inline["description_inline"]  = true

      ##~ @parameter_referrer = {"name" => "referrer", "dataType" => "string", "required" => false, "paramType" => "query"}
      ##~ @parameter_referrer["description"] = "Referrer IP Address or Domain. Required only if referrer filtering is enabled. If special value '*' (wildcard) is passed, the referrer check is bypassed."
      ##
      ##~ @parameter_redirect_url = {"name" => "redirect_url", "dataType" => "string", "required" => false, "paramType" => "query"}
      ##~ @parameter_redirect_url["description"] = "Optional redirect URL for OAuth. Will be validated if sent."
      ##
      ##~ @parameter_redirect_uri = {"name" => "redirect_uri", "dataType" => "string", "required" => false, "paramType" => "query"}
      ##~ @parameter_redirect_uri["description"] = "Optional redirect URI for OAuth. This is the same as 'redirect_url', but if used you should expect a matching 'redirect_uri' response field."
      ##

      ##~ @parameter_usage = {"name" => "usage", "dataType" => "hash", "required" => false, "paramType" => "query", "allowMultiple" => false}
      ##~ @parameter_usage["description"] = "Usage will increment the metrics with the values passed. The value can be only a positive integer (e.g. 1, 50). Reporting usage[hits]=1 will increment the hits counter by +1."
      ##
      ##~ @parameter_usage_fields = {"name" => "metric", "dataType" => "custom", "required" => false, "paramType" => "query", "allowMultiple" => true, "threescale_name" => "metric_names"}
      ##~ @parameter_usage_fields["description"] = "Metric to be reported"
      ##
      ##~ @parameter_usage["parameters"] = []
      ##~ @parameter_usage["parameters"] << @parameter_usage_fields
      ##
      ##~ @parameter_usage_predicted = {"name" => "usage", "dataType" => "hash", "required" => false, "paramType" => "query", "allowMultiple" => false}
      ##~ @parameter_usage_predicted["description"] = "Predicted Usage. Actual usage will need to be reported with a report or an authrep."
      ##
      ##~ @parameter_usage_predicted["parameters"] = []
      ##~ @parameter_usage_predicted["parameters"] << @parameter_usage_fields
      ##
      ##~ @timestamp = {"name" => "timestamp", "dataType" => "string", "required" => false, "paramType" => "query"}
      ##~ @timestamp["description"] = "If passed, it should be the time when the transaction took place. Format: Either a UNIX UTC timestamp (seconds from the UNIX Epoch), or YYYY-MM-DD HH:MM:SS for UTC, add -HH:MM or +HH:MM for time offset. For instance, 2011-12-30 22:15:31 -08:00."
      ##~ @timestamp["description_inline"] = true
      ##
      ##~ @parameter_log = {"name" => "log", "dataType" => "hash", "required" => false, "paramType" => "query", "allowMultiple" => false}
      ##~ @parameter_log["description"] = "Request Log allows to log status codes of your API back to 3scale to maintain a log of the latest activity on your API. Request Logs are optional and not available in all 3scale plans."
      ##
      ##~ @parameter_log_field_code = {"name" => "code", "dataType" => "string", "paramType" => "query", "description_inline" => true}
      ##~ @parameter_log_field_code["description"] = "Response code of the response from your API (needs to be URL encoded). Optional. Truncated after 32bytes."


      ##~ @parameter_log["parameters"] = []
      ##~ @parameter_log["parameters"] << @parameter_log_field_code
      ##
      ##~ @parameter_transaction_app_id = {"name" => "transactions", "dataType" => "array", "required" => true, "paramType" => "query", "allowMultiple" => true}
      ##~ @parameter_transaction_app_id["description"] = "Transactions to be reported. There is a limit of 1000 transactions to be reported on a single request."
      ##~ @parameter_transaction_app_id["parameters"] = []
      ##
      ##~ @parameter_transaction_app_id["parameters"] << @parameter_app_id_inline
      ##~ @parameter_transaction_app_id["parameters"] << @timestamp
      ##~ @parameter_transaction_app_id["parameters"] << @parameter_usage
      ##~ @parameter_transaction_app_id["parameters"] << @parameter_log

      ##~ @parameter_transaction_api_key = {"name" => "transactions", "dataType" => "array", "required" => true, "paramType" => "query", "allowMultiple" => true}
      ##~ @parameter_transaction_api_key["description"] = "Transactions to be reported. There is a limit of 1000 transactions to be reported on a single request."
      ##~ @parameter_transaction_api_key["parameters"] = []

      ##~ @parameter_transaction_api_key["parameters"] << @parameter_user_key_inline
      ##~ @parameter_transaction_api_key["parameters"] << @timestamp
      ##~ @parameter_transaction_api_key["parameters"] << @parameter_usage
      ##~ @parameter_transaction_api_key["parameters"] << @parameter_log

      ##~ @parameter_transaction_oauth = {"name" => "transactions", "dataType" => "array", "required" => true, "paramType" => "query", "allowMultiple" => true}
      ##~ @parameter_transaction_oauth["description"] = "Transactions to be reported. There is a limit of 1000 transactions to be reported on a single request."
      ##~ @parameter_transaction_oauth["parameters"] = []

      ##~ @parameter_transaction_oauth["parameters"] << @parameter_client_id_inline
      ##~ @parameter_transaction_oauth["parameters"] << @timestamp
      ##~ @parameter_transaction_oauth["parameters"] << @parameter_usage
      ##~ @parameter_transaction_oauth["parameters"] << @parameter_log


      AUTH_AUTHREP_COMMON_PARAMS = ['service_id'.freeze, 'app_id'.freeze, 'app_key'.freeze,
                                    'user_key'.freeze, 'provider_key'.freeze].freeze
      private_constant :AUTH_AUTHREP_COMMON_PARAMS

      REPORT_EXPECTED_PARAMS = ['provider_key'.freeze,
                                'service_token'.freeze,
                                'service_id'.freeze,
                                'transactions'.freeze].freeze
      private_constant :REPORT_EXPECTED_PARAMS

      configure :production do
        disable :dump_errors
      end

      use Backend::Rack::ExceptionCatcher

      before do
        content_type 'application/vnd.3scale-v2.0+xml'.freeze
        # enable CORS for all our endpoints
        response.headers.merge!(CORS.headers)
        # enable CSP for all our endpoints
        response.headers.merge!(CSP.headers)
      end

      # Enable CORS pre-flight request for all our endpoints
      options '*' do
        response.headers.merge!(CORS.options_headers)
        204
      end

      # this is an HAProxy-specific endpoint, equivalent to
      # their '/haproxy?monitor' one, just renamed to available.
      # returning 200 here means we're up willing to take requests.
      # returning 404 makes HAProxy consider us down soon(ish),
      # taking into account that usually several HAProxies contain
      # us in their listener pool and it takes for all of them to
      # notice before no request is received.
      head '/available' do
        200
      end

      def do_api_method(method_name)
        halt 403 if params.nil?

        normalize_non_empty_keys!

        provider_key = params[:provider_key] ||
          provider_key_from(params[:service_token], params[:service_id])

        raise_provider_key_error(params) if blank?(provider_key)

        check_no_user_id

        halt 403 unless valid_usage_params?

        # As params is passed to other methods, we need to overwrite the
        # provider key. Some methods assume that params[:provider_key] is
        # not null/empty.
        params[:provider_key] = provider_key

        log_without_unused_attrs(params[:log]) if params[:log]

        auth_status = Transactor.send method_name, provider_key, params, request: request_info
        response_auth_call(auth_status)
      rescue ThreeScale::Backend::Error => error
        begin
          ErrorStorage.store(service_id, error, response_code: 403, request: request_info)
        rescue ProviderKeyInvalid
          # This happens trying to load the service id
        ensure
          raise error
        end
      end
      private :do_api_method

      ## ------------ DOCS --------------
      ##~ namespace = "Service Management API"
      ##~ sapi = source2swagger.namespace(namespace)
      ##~ a = sapi.apis.add
      ##~ a.set "path" => "/transactions/authorize.xml", "format" => "xml"
      ##~ op = a.operations.add
      ##~ op.set :httpMethod => "GET"
      ##~ op.summary = "Authorize (App Id authentication pattern)"
      ##
      ##~ @authorize_desc = "<p>It is used to check if a particular application exists,"
      ##~ @authorize_desc = @authorize_desc + " is active and is within its usage limits. It can be optionally used to authenticate a call using an application key."
      ##~ @authorize_desc = @authorize_desc + " It's possible to pass a 'predicted usage' to the authorize call. This can serve three purposes:<p>1) To make sure an API"
      ##~ @authorize_desc = @authorize_desc + " call won't go over the limits before the call is made, if the usage of the call is known in advance. In this case, the"
      ##~ @authorize_desc = @authorize_desc + " estimated usage can be passed to the authorize call, and it will respond whether the actual API call is still within limit."
      ##~ @authorize_desc = @authorize_desc + " <p>2) To limit the authorization only to a subset of metrics. If usage is passed in, only the metrics listed in it will"
      ##~ @authorize_desc = @authorize_desc + " be checked against the limits. For example: There are two metrics defined: <em>searches</em> and <em>updates</em>. <em>updates</em> are already over"
      ##~ @authorize_desc = @authorize_desc + " limit, but <em>searches</em> are not. In this case, the user should still be allowed to do a search call, but not an update one."
      ##~ @authorize_desc = @authorize_desc + " And, <p>3) If no usage is passed then any metric with a limit exceeded state will result in an _authorization_failed_ response."
      ##~ @authorize_desc = @authorize_desc + "<p><b>Note:</b> Even if the predicted usage is passed in, authorize is still a <b>read-only</b> operation. You have to make the report call"
      ##~ @authorize_desc = @authorize_desc + " to report the usage."
      ##
      ##~ @authorize_desc_response = "<p>The response can have an http response code: <code class='http'>200</code> OK (if authorization is granted), <code class='http'>409</code> (if it's not granted, typically application over limits or keys missing, check 'reason' tag), "
      ##~ @authorize_desc_response = @authorize_desc_response + " or <code class='http'>403</code> (for authentication errors, check 'error' tag) and <code class='http'>404</code> (not found)."

      ##~ op.description = "<p>Read-only operation to authorize an application in the App Id authentication pattern." + " "+ @authorize_desc + " " + @authorize_desc_response
      ##~ op.group = "authorize"
      ##
      ##~ op.parameters.add @parameter_service_token
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_app_id
      ##~ op.parameters.add @parameter_app_key
      ##~ op.parameters.add @parameter_referrer
      ##~ op.parameters.add @parameter_usage_predicted
      ##
      ##~ a = sapi.apis.add
      ##~ a.set "path" => "/transactions/authorize.xml", "format" => "xml"
      ##~ op = a.operations.add
      ##~ op.set :httpMethod => "GET", :tags => ["authorize","user_key"], :nickname => "authorize_user_key", :deprecated => false
      ##~ op.summary = "Authorize (API Key authentication pattern)"
      ##
      ##~ op.description = "Read-only operation to authorize an application in the App Key authentication pattern." + " "+ @authorize_desc + " " + @authorize_desc_response
      ##~ op.group = "authorize"
      ##
      ##~ op.parameters.add @parameter_service_token
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_user_key
      ##~ op.parameters.add @parameter_referrer
      ##~ op.parameters.add @parameter_usage_predicted
      ##
      get '/transactions/authorize.xml' do
        do_api_method :authorize
      end

      ## ------------ DOCS --------------
      ##~ namespace = "Service Management API"
      ##~ sapi = source2swagger.namespace(namespace)
      ##~ a = sapi.apis.add
      ##~ a.set "path" => "/transactions/oauth_authorize.xml", "format" => "xml"
      ##~ op = a.operations.add
      ##~ op.set :httpMethod => "GET", :tags => ["authorize","user_key"], :nickname => "oauth_authorize", :deprecated => false
      ##~ op.summary = "Authorize (OAuth authentication mode pattern)"
      ##
      ##~ op.description = "<p>Read-only operation to authorize an application in the OAuth authentication pattern."
      ##~ @oauth_security = "<p>When using this endpoint please pay attention at your handling of app_id and app_key parameters. If you don't specify an app_key, the endpoint assumes the app_id specified has already been authenticated by other means. If you specify the app_key parameter, even if it is empty, it will be checked against the application's keys. If you don't trust the app_id value you have, use app keys and specify one."
      ##~ @oauth_desc_response = "<p>This call returns extra data (secret and redirect_url) needed to power OAuth APIs. It's only available for users with OAuth enabled APIs."
      ##~ op.description = op.description + @oauth_security + @oauth_desc_response
      ##~ op.description = op.description + " " + @authorize_desc + " " + @authorize_desc_response
      ##~ @parameter_app_key_oauth = {"name" => "app_key", "dataType" => "string", "required" => false, "paramType" => "query", "threescale_name" => "app_keys"}
      ##~ @parameter_app_key_oauth["description"] = "App Key (shared secret of the application). The app key, if present, must match a key defined for the application. Note that empty values are considered invalid."
      #
      ##~ op.group = "authorize"
      ##
      ##~ op.parameters.add @parameter_service_token
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_client_id
      ##~ op.parameters.add @parameter_app_key_oauth
      ##~ op.parameters.add @parameter_referrer
      ##~ op.parameters.add @parameter_usage_predicted
      ##~ op.parameters.add @parameter_redirect_url
      ##~ op.parameters.add @parameter_redirect_uri
      ##
      get '/transactions/oauth_authorize.xml' do
        do_api_method :oauth_authorize
      end

      ## ------------ DOCS --------------
      ##~ namespace = "Service Management API"
      ##~ sapi = source2swagger.namespace(namespace)
      ##~ a = sapi.apis.add
      ##~ a.set "path" => "/transactions/authrep.xml", "format" => "xml"
      ##~ op = a.operations.add
      ##~ op.set :httpMethod => "GET"
      ##~ op.summary = "AuthRep (Authorize + Report for the App Id authentication pattern)"
      ##
      ##~ @authrep_desc_base = "<p>Authrep is a <b>'one-shot'</b> operation to authorize an application and report the associated transaction at the same time."
      ##~ @authrep_desc = "<p>The main difference between this call and the regular authorize call is that"
      ##~ @authrep_desc = @authrep_desc + " usage will be reported if the authorization is successful. Authrep is the most convenient way to integrate your API with the"
      ##~ @authrep_desc = @authrep_desc + " 3scale's Service Manangement API since it does a 1:1 mapping between a request to your API and a request to 3scale's API."
      ##~ @authrep_desc = @authrep_desc + "<p>If you do not want to do a request to 3scale for each request to your API or batch the reports you should use the Authorize and Report methods instead."
      ##~ @authrep_desc = @authrep_desc + "<p>Authrep is <b>not a read-only</b> operation and will increment the values if the authorization step is a success."
      ##
      ##~ op.description = @authrep_desc_base + @authrep_desc
      ##~ op.group = "authrep"
      ##
      ##~ op.parameters.add @parameter_service_token
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_app_id
      ##~ op.parameters.add @parameter_app_key
      ##~ op.parameters.add @parameter_referrer
      ##~ op.parameters.add @parameter_usage
      ##~ op.parameters.add @parameter_log
      ##
      ##
      ##~ a = sapi.apis.add
      ##~ a.set "path" => "/transactions/authrep.xml", "format" => "xml"
      ##~ op = a.operations.add
      ##~ op.set :httpMethod => "GET"
      ##~ op.summary = "AuthRep (Authorize + Report for the API Key authentication pattern)"
      ##~ op.description = @authrep_desc_base + @authrep_desc
      ##~ op.group = "authrep"
      ##
      ##~ op.parameters.add @parameter_service_token
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_user_key
      ##~ op.parameters.add @parameter_referrer
      ##~ op.parameters.add @parameter_usage
      ##~ op.parameters.add @parameter_log
      ##
      get '/transactions/authrep.xml' do
        do_api_method :authrep
      end

      ## ------------ DOCS --------------
      ##~ namespace = "Service Management API"
      ##~ sapi = source2swagger.namespace(namespace)
      ##~ a = sapi.apis.add
      ##~ a.set "path" => "/transactions/oauth_authrep.xml", "format" => "xml"
      ##~ op = a.operations.add
      ##~ op.set :httpMethod => "GET", :nickname => "oauth_authrep", :deprecated => false
      ##~ op.summary = "AuthRep (OAuth authentication mode pattern)"
      ##
      ##~ op.description = "<p>Authrep is a <b>'one-shot'</b> operation to authorize an application and report the associated transaction at the same time in the OAuth authentication pattern."
      ##~ op.description = op.description + @authrep_desc + @oauth_security + @oauth_desc_response
      ##~ op.group = "authrep"
      ##
      ##~ op.parameters.add @parameter_service_token
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_client_id
      ##~ op.parameters.add @parameter_app_key_oauth
      ##~ op.parameters.add @parameter_referrer
      ##~ op.parameters.add @parameter_usage
      ##~ op.parameters.add @parameter_log
      ##~ op.parameters.add @parameter_redirect_url
      ##~ op.parameters.add @parameter_redirect_uri
      ##
      get '/transactions/oauth_authrep.xml' do
        do_api_method :oauth_authrep
      end

      ## ------------ DOCS --------------
      ##~ namespace = "Service Management API"
      ##~ sapi = source2swagger.namespace(namespace)
      ##~ a = sapi.apis.add
      ##~ a.set "path" => "/transactions.xml", "format" => "xml"
      ##~ op = a.operations.add
      ##~ op.set :httpMethod => "POST"
      ##~ op.summary = "Report (App Id authentication pattern)"

      ##~ @post_notes = "<p>Supported <code class='http'>Content-Type</code> values for this POST call are: <code class='http'>application/x-www-form-urlencoded</code>."
      ##~ @report_desc = "<p>Report the transactions to 3scale backend.<p>This operation updates the metrics passed in the usage parameter. You can send up to 1K"
      ##~ @report_desc = @report_desc + " transactions in a single POST request. Transactions are processed asynchronously by the 3scale's backend."
      ##~ @report_desc = @report_desc + "<p>Transactions from a single batch are reported only if all of them are valid. If there is an error in"
      ##~ @report_desc = @report_desc + " processing of at least one of them, none is reported.<p>Note that a batch can only report transactions to the same"
      ##~ @report_desc = @report_desc + " service, <em>service_id</em> is at the same level that <em>service_token</em>. Multiple report calls will have to be issued to report"
      ##~ @report_desc = @report_desc + " transactions to different services."
      ##~ @report_desc = @report_desc + "<p>Be aware that reporting metrics that are limited at the time of reporting will have no effect."
      ##~ @report_desc = @report_desc + @post_notes
      ##
      ##~ op.description = @report_desc
      ##~ op.group = "report"
      #
      ##~ op.parameters.add @parameter_service_token
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_transaction_app_id
      ##
      ##~ a = sapi.apis.add
      ##~ a.set "path" => "/transactions.xml", "format" => "xml"
      ##~ op = a.operations.add
      ##~ op.set :httpMethod => "POST"
      ##~ op.summary = "Report (API Key authentication pattern)"
      ##~ op.description = @report_desc
      ##~ op.group = "report"
      #
      ##~ op.parameters.add @parameter_service_token
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_transaction_api_key
      ##
      ##~ a = sapi.apis.add
      ##~ a.set "path" => "/transactions.xml", "format" => "xml"
      ##~ op = a.operations.add
      ##~ op.set :httpMethod => "POST"
      ##~ op.summary = "Report (OAuth authentication pattern)"
      ##~ op.description = @report_desc
      ##~ op.group = "report"
      #
      ##~ op.parameters.add @parameter_service_token
      ##~ op.parameters.add @parameter_service_id
      ##~ op.parameters.add @parameter_transaction_oauth
      ##
      ##
      post '/transactions.xml' do
        check_post_content_type!

        # 403 Forbidden for consistency (but we should return 400 Bad Request)
        if params.nil?
          logger.notify("listener: params hash is nil in method '/transactions.xml'")
          halt 403
        end

        # returns 403 when no provider key is given, even if other params have an invalid encoding
        provider_key = params[:provider_key] ||
          provider_key_from(params[:service_token], params[:service_id])

        raise_provider_key_error(params) if blank?(provider_key)

        # no need to check params key encoding. Sinatra framework does it for us.
        check_params_value_encoding!(params, REPORT_EXPECTED_PARAMS)

        transactions = params[:transactions]
        check_transactions_validity(transactions)

        transactions.values.each do |tr|
          log_without_unused_attrs(tr['log']) if tr['log']
        end

        Transactor.report(provider_key, params[:service_id], transactions, response_code: 202, request: request_info)
        202
      end

      get '/check.txt' do
        content_type 'text/plain'
        body 'ok'
      end

      # using a class variable instead of settings because we want this to be
      # as fast as possible when responding, since we hit /status a lot.
      @@status = { status: :ok,
                   version: { backend: ThreeScale::Backend::VERSION } }.to_json.freeze

      get '/status' do
        content_type 'application/json'.freeze
        @@status
      end

      @@not_found = [404, { 'Content-Type' => 'application/vnd.3scale-v2.0+xml' }, ['']].freeze

      not_found do
        env['sinatra.error'.freeze] = nil
        @@not_found
      end

      private

      def blank?(object)
        !object || object.respond_to?(:empty?) && object.empty?
      end

      def valid_usage_params?
        params[:usage].nil? || params[:usage].is_a?(Hash)
      end

      def check_params_value_encoding!(input_params, params_to_validate)
        params_to_validate.each do |p|
          param_value = input_params[p]
          if !param_value.nil? && !param_value.valid_encoding?
            halt 400, ThreeScale::Backend::NotValidData.new.to_xml
          end
        end
      end

      def normalize_non_empty_keys!
        AUTH_AUTHREP_COMMON_PARAMS.each do |p|
          thisparam = params[p]
          if !thisparam.nil?
            if thisparam.class != String
              params[p] = nil
            else
              unless thisparam.valid_encoding?
                halt 400, ThreeScale::Backend::NotValidData.new.to_xml
              end
              contents = thisparam.strip
              # Unfortunately some users send empty app_keys that should have
              # been populated for some OAuth flows - this poses a problem
              # because app_key must be kept even if empty if it exists as it is
              # semantically different for authorization endpoints (ie. it
              # forces authentication to happen).
              if p == 'app_key'.freeze
                params[p] = contents
              else
                params[p] = nil if contents.empty?
              end
            end
          end
        end
      end

      def invalid_post_content_type?(content_type)
        content_type && !content_type.empty? &&
          content_type != 'application/x-www-form-urlencoded'.freeze &&
          content_type != 'multipart/form-data'.freeze
      end

      def check_post_content_type!
        ctype = request.media_type
        raise ContentTypeInvalid, ctype if invalid_post_content_type?(ctype)
      end

      def check_transactions_validity(transactions)
        if blank?(transactions)
          raise TransactionsIsBlank
        end

        if !transactions.is_a?(Hash)
          raise TransactionsFormatInvalid
        end

        if transactions.any? { |_id, data| data.nil? }
          raise TransactionsHasNilTransaction
        end

        if transactions.any? { |_id, data| data.is_a?(Hash) && data[:user_id] }
          raise EndUsersNoLongerSupported
        end
      end

      # In the past, the log field in a transaction could also include
      # "response" and "request". Those fields are not used anymore, but some
      # callers are still sending them. We want to filter them to avoid storing
      # them in the job queues, decoding them, etc. unnecessarily.
      def log_without_unused_attrs(log)
        log.select! { |k| k == 'code' }
      end

      # In previous versions it was possible to authorize by end-user.
      # Apisonator used the "user_id" param to do that.
      # That's no longer supported, and we want to raise an error when we
      # detect that param to let the user know that.
      def check_no_user_id
        if params && params[:user_id]
          raise EndUsersNoLongerSupported
        end
      end

      def service_id
        if params[:service_id].nil? || params[:service_id].empty?
          @service_id ||= Service.default_id!(params[:provider_key])
        else
          unless Service.authenticate_service_id(params[:service_id], params[:provider_key])
            raise ProviderKeyInvalid, params[:provider_key]
          end
          @service_id ||= params[:service_id]
        end
      end

      def request_info
        {
          url: request.url,
          method: request.request_method,
          form_vars: request.env["rack.request.form_vars"],
          user_agent: request.user_agent,
          ip: request.ip,
          content_type: request.content_type,
          content_length: request.content_length,
          extensions: threescale_extensions,
        }
      end

      def provider_key_from(service_token, service_id)
        if blank?(service_token) ||
            blank?(service_id) ||
            !ServiceToken.exists?(service_token, service_id)
          nil
        else
          Service.provider_key_for(service_id)
        end
      end

      # Raises the appropriate error when provider key is blank.
      # Provider key is blank only when these 2 conditions are met:
      #   1) It is not received by parameter (params[:provider_key] is nil)
      #   2) It cannot be obtained using a service token and a service ID.
      #      This can happen when these 2 are not received or when the pair is
      #      not associated with a provider key.
      def raise_provider_key_error(params)
        token, id = params[:service_token], params[:service_id]
        raise ProviderKeyOrServiceTokenRequired if blank?(token)
        raise ServiceIdMissing if blank?(id)
        raise ServiceTokenInvalid.new(token, id)
      end

      def response_auth_call(auth_status)
        status(auth_status.authorized? ? 200 : 409)
        optionally_set_headers(auth_status)
        body(threescale_extensions[:no_body] ? nil : auth_status.to_xml)
      end

      def optionally_set_headers(auth_status)
        set_rejection_reason_header(auth_status)
        set_limit_headers(auth_status)
      end

      def set_rejection_reason_header(auth_status)
        if !auth_status.authorized? &&
            threescale_extensions[:rejection_reason_header] == '1'.freeze
          response['3scale-rejection-reason'.freeze] = auth_status.rejection_reason_code
        end
      end

      def set_limit_headers(auth_status)
        if threescale_extensions[:limit_headers] == '1'.freeze &&
            (auth_status.authorized? || auth_status.rejection_reason_code == LimitsExceeded.code)
          auth_status.limit_headers.each do |hdr, value|
            response["3scale-limit-#{hdr}"] = value.to_s
          end
        end
      end

      def threescale_extensions
        @threescale_extensions ||= self.class.threescale_extensions request.env, params
      end

      # Listener.threescale_extensions - this is a public class method
      #
      # Collect 3scale extensions or optional features.
      def self.threescale_extensions(env, params = nil)
        options = env['HTTP_3SCALE_OPTIONS'.freeze]
        if options
          ::Rack::Utils.parse_nested_query(options).symbolize_names
        else
          {}
        end.tap do |ext|
          # no_body must be supported from URL params, as it has users
          no_body = ext[:no_body] || deprecated_no_body_param(env, params)
          # This particular param was expected to be specified (no matter the
          # value) or having the string 'true' as value. We are going to
          # accept any value except '0' or 'false'.
          if no_body
            ext[:no_body] = no_body != 'false' && no_body != '0'
          end
        end
      end

      def self.deprecated_no_body_param(env, params)
        if params.nil?
          # check the request parameters from the Rack environment
          qh = env['rack.request.query_hash'.freeze]
          qh['no_body'.freeze] unless qh.nil?
        else
          params[:no_body]
        end
      end

      private_class_method :deprecated_no_body_param
    end
  end
end
