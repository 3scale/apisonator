require '3scale/backend/transactor/notify_batcher'
require '3scale/backend/transactor/notify_job'
require '3scale/backend/transactor/process_job'
require '3scale/backend/transactor/report_job'
require '3scale/backend/transactor/usage_report'
require '3scale/backend/transactor/status'
require '3scale/backend/transactor/limit_headers'
require '3scale/backend/errors'
require '3scale/backend/validators'
require '3scale/backend/stats/keys'

module ThreeScale
  module Backend
    # Methods for reporting and authorizing transactions.
    module Transactor
      include Backend::StorageKeyHelpers
      include NotifyBatcher
      extend self

      def report(provider_key, service_id, transactions, context_info = {})
        service = Service.load_with_provider_key!(service_id, provider_key)

        report_enqueue(service.id, transactions, context_info)
        notify_report(provider_key, transactions.size)
      end

      def authorize(provider_key, params, extensions = {})
        do_authorize :authorize, provider_key, params, extensions
      end

      def oauth_authorize(provider_key, params, extensions = {})
        do_authorize :oauth_authorize, provider_key, params, extensions
      end

      def authrep(provider_key, params, extensions = {})
        do_authrep :authrep, provider_key, params, extensions
      end

      def oauth_authrep(provider_key, params, extensions = {})
        do_authrep :oauth_authrep, provider_key, params, extensions
      end

      def utilization(service_id, application_id)
        application = Application.load!(service_id, application_id)
        application.load_metric_names
        usage = Usage.application_usage(application, Time.now.getutc)
        status = Status.new(service_id: service_id,
                            application: application,
                            values: usage)
        Validators::Limits.apply(status, {})
        status.application_usage_reports
      end

      private

      def validate(oauth, provider_key, report_usage, params, extensions)
        service = Service.load_with_provider_key!(params[:service_id], provider_key)
        # service_id cannot be taken from params since it might be missing there
        service_id = service.id

        app_id, user_id = params[:app_id], params[:user_id]
        # TODO: make sure params are nil if they are empty up the call stack
        # Note: app_key is an exception, as it being empty is semantically
        # significant.
        params[:app_id] = nil if app_id && app_id.empty?
        params[:user_id] = nil if user_id && user_id.empty?

        # Now OAuth tokens also identify users, so must check tokens anyway if
        # at least one of app or user ids is missing.
        #
        # NB: so what happens if we call an OAuth method with user_key=K and
        # user_id=U? It is effectively as if app_id was given and no token would
        # need to be checked, but we do... That is not consistent. And madness.
        # Each time I try to understand this I feel I'm becoming dumber...
        #
        if oauth
          if user_id.nil? || app_id.nil?
            access_token = params[:access_token]
            access_token = nil if access_token && access_token.empty?

            if access_token.nil?
              raise ApplicationNotFound.new nil if app_id.nil?
            else
              app_id, user_id = get_token_ids(access_token, service_id,
                                              app_id, user_id)
              # update params, since they are checked elsewhere
              params[:app_id] = app_id
              params[:user_id] = user_id
            end
          end

          validators = Validators::OAUTH_VALIDATORS
        else
          validators = Validators::VALIDATORS
        end

        params[:user_key] = nil if params[:user_key] && params[:user_key].empty?
        application = Application.load_by_id_or_user_key!(service_id,
                                                          app_id,
                                                          params[:user_key])

        user         = load_user!(application, service, user_id)
        now          = Time.now.getutc
        usage_values = Usage.application_usage(application, now)
        user_usage   = Usage.user_usage(user, now) if user
        status_attrs = {
          service_id:      service_id,
          user_values:     user_usage,
          application:     application,
          oauth:           oauth,
          usage:           params[:usage],
          predicted_usage: !report_usage,
          values:          usage_values,
          # hierarchy parameter adds information in the response needed
          # to derive which limits affect directly or indirectly the
          # metrics for which authorization is requested.
          hierarchy:       extensions[:hierarchy] == '1',
          user:            user,
        }

        application.load_metric_names
        user.load_metric_names if user

        # returns a status object
        apply_validators(validators, status_attrs, params)
      end

      def get_token_ids(token, service_id, app_id, user_id)
        begin
          token_aid, token_uid = OAuth::Token::Storage.
                                   get_credentials(token, service_id)
        rescue AccessTokenInvalid => e
          # Yep, well, er. Someone specified that it is OK to have an
          # invalid token if an app_id is specified. Somehow passing in
          # a user_key is still not enough, though...
          raise e if app_id.nil?
        end

        # We only take the token ids into account if we had no parameter ids
        if app_id.nil?
          app_id = token_aid
        end
        if user_id.nil?
          user_id = token_uid
        end

        [app_id, user_id]
      end

      def do_authorize(method, provider_key, params, extensions)
        notify_authorize(provider_key)
        validate(method == :oauth_authorize, provider_key, false, params, extensions)
      end

      def do_authrep(method, provider_key, params, extensions)
        status = begin
                   validate(method == :oauth_authrep, provider_key, true, params, extensions)
                 rescue ApplicationNotFound, UserNotDefined => e
                   # we still want to track these
                   notify_authorize(provider_key)
                   raise e
                 end

        usage = params[:usage]

        if (usage || params[:log]) && status.authorized?
          application_id = status.application.id
          username = status.user.username unless status.user.nil?
          report_enqueue(status.service_id, ({ 0 => {"app_id" => application_id, "usage" => usage, "user_id" => username, "log" => params[:log]}}), {})
          notify_authrep(provider_key, usage ? usage.size : 0)
        else
          notify_authorize(provider_key)
        end

        status
      end

      def load_user!(application, service, user_id)
        user = nil

        if not (user_id.nil? || user_id.empty? || !user_id.is_a?(String))
          ## user_id on the paramters
          if application.user_required?
            user = User.load_or_create!(service, user_id)
            raise UserRequiresRegistration, service.id, user_id unless user
          end
        else
          raise UserNotDefined, application.id if application.user_required?
        end

        user
      end

      # This method applies the validators in the given order. If there is one
      # that fails, it stops there instead of applying all of them.
      # Returns a Status instance.
      def apply_validators(validators, status_attrs, params)
        status = Status.new(status_attrs)
        validators.all? { |validator| validator.apply(status, params) }
        status
      end

      def report_enqueue(service_id, data, context_info)
        Resque.enqueue(ReportJob, service_id, data, Time.now.getutc.to_f, context_info)
      end

      def storage
        Storage.instance
      end
    end
  end
end
