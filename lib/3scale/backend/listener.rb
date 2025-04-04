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

      AUTH_AUTHREP_COMMON_PARAMS = ['service_id'.freeze, 'app_id'.freeze, 'app_key'.freeze,
                                    'user_key'.freeze, 'provider_key'.freeze].freeze
      private_constant :AUTH_AUTHREP_COMMON_PARAMS

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

        check_params_encoding!(params)
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

        filter_log_param(params)

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

      get '/transactions/authorize.xml' do
        do_api_method :authorize
      end

      get '/transactions/oauth_authorize.xml' do
        do_api_method :oauth_authorize
      end

      get '/transactions/authrep.xml' do
        do_api_method :authrep
      end

      get '/transactions/oauth_authrep.xml' do
        do_api_method :oauth_authrep
      end

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

        check_params_encoding!(params)

        transactions = params[:transactions]
        check_transactions_validity(transactions)

        transactions.values.each do |tr|
          filter_log_param(tr, 'log')
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

      def check_params_encoding!(input_params)
        input_params.each do |key, value|
          raise ArgumentError, Rack::ExceptionCatcher::INVALID_BYTE_SEQUENCE_ERR_MSG unless key.valid_encoding?

          if !value.nil? && !value.valid_encoding?
            raise ArgumentError, Rack::ExceptionCatcher::INVALID_BYTE_SEQUENCE_ERR_MSG
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
                raise ArgumentError, Rack::ExceptionCatcher::INVALID_BYTE_SEQUENCE_ERR_MSG
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
      # Also, discard logs that don't have the 'code' attribute
      def filter_log_param(params, key = :log)
        log_param = params[key]

        if log_param.is_a?(Hash) && log_param['code']
          params[key] = log_param.slice('code')
        else
          params.delete(key)
        end
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
