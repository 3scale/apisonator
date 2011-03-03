require '3scale/backend/transactor/notify_job'
require '3scale/backend/transactor/process_job'
require '3scale/backend/transactor/report_job'
require '3scale/backend/transactor/status'

module ThreeScale
  module Backend
    # Methods for reporting and authorizing transactions.
    module Transactor
      include Core::StorageKeyHelpers

      extend self

      def report(provider_key, transactions)
        service_id = Service.load_id!(provider_key)
        Resque.enqueue(ReportJob, service_id, transactions)

        notify(provider_key, 'transactions/create_multiple' => 1,
                             'transactions' => transactions.size)
      end

      VALIDATORS = [Validators::Key,
                    Validators::Referrer,
                    Validators::ReferrerFilters,
                    Validators::State,
                    Validators::Limits]

      OAUTH_VALIDATORS = [Validators::OauthSetting,
                          Validators::OauthKey,
                          Validators::RedirectUrl,
                          Validators::Referrer,
                          Validators::ReferrerFilters,
                          Validators::State,
                          Validators::Limits]

      def authorize(provider_key, params)
        notify(provider_key, 'transactions/authorize' => 1)

        service     = Service.load!(provider_key)
        application = Application.load_by_id_or_user_key!(service.id,
                                                          params[:app_id],
                                                          params[:user_key])
        usage       = load_current_usage(application)

        Status.new(:service     => service,
                   :application => application,
                   :values      => usage).tap do |status|
          VALIDATORS.all? do |validator|
            if validator == Validators::Referrer && !status.service.referrer_filters_required?
              true
            else
              validator.apply(status, params)
            end
          end
        end
      end

      def oauth_authorize(provider_key, params)
        notify(provider_key, 'transactions/authorize' => 1)

        service     = Service.load!(provider_key)
        application = Application.load_by_id_or_user_key!(service.id,
                                                          params[:app_id],
                                                          params[:user_key])
        usage       = load_current_usage(application)

        Status.new(:service     => service,
                   :application => application,
                   :values      => usage).tap do |status|
          OAUTH_VALIDATORS.all? do |validator|
            if validator == Validators::Referrer && !status.service.referrer_filters_required?
              true
            else
              validator.apply(status, params)
            end
          end
        end
      end

      def authrep(provider_key, params)
        service     = Service.load!(provider_key)
        application = Application.load_by_id_or_user_key!(service.id,
                                                          params[:app_id],
                                                          params[:user_key])
        usage       = load_current_usage(application)
        status = Status.new(:service     => service,
                   :application => application,
                   :values      => usage).tap do |status|
          VALIDATORS.all? do |validator|
            if validator == Validators::Referrer && !status.service.referrer_filters_required?
              true
            else
              validator.apply(status, params)
            end
          end
        end

        if status.authorized? && !params[:usage].nil? && !params[:usage].empty?
          Resque.enqueue(ReportJob, service.id, ({ 0 => {"app_id" => application.id, "usage" => params[:usage]}}))
          notify(provider_key, 'transactions/authorize' => 1, 'transactions/create_multiple' => 1, 'transactions' => params[:usage].size)
        else
          notify(provider_key, 'transactions/authorize' => 1)
        end
        status
      rescue ThreeScale::Backend::ApplicationNotFound => e # we still want to track these
        notify(provider_key, 'transactions/authorize' => 1)
        raise e
      end

      private

      def notify(provider_key, usage)
        Resque.enqueue(NotifyJob, provider_key, usage, encode_time(Time.now.getutc))
      end

      def encode_time(time)
        time.to_s
      end

      def parse_predicted_usage(service, usage)
      end

      def load_current_usage(application)
        pairs = application.usage_limits.map do |usage_limit|
          [usage_limit.metric_id, usage_limit.period]
        end

        return {} if pairs.empty?

        # preloading metric names
        application.metric_names = ThreeScale::Core::Metric.load_all_names(application.service_id, pairs.map{|e| e.first}.uniq)

        now = Time.now.getutc

        keys = pairs.map do |metric_id, period|
          usage_value_key(application, metric_id, period, now)
        end

        raw_values = storage.mget(*keys)
        values     = {}

        pairs.each_with_index do |(metric_id, period), index|
          values[period] ||= {}
          values[period][metric_id] = raw_values[index].to_i
        end

        values
      end

      def usage_value_key(application, metric_id, period, time)
        encode_key("stats/{service:#{application.service_id}}/" +
                   "cinstance:#{application.id}/metric:#{metric_id}/" +
                   "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
      end

      def storage
        Storage.instance
      end
    end
  end
end
