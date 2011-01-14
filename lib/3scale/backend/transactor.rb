module ThreeScale
  module Backend
    # Methods for reporting and authorizing transactions.
    module Transactor
      autoload :NotifyJob,  '3scale/backend/transactor/notify_job'
      autoload :ProcessJob, '3scale/backend/transactor/process_job'
      autoload :ReportJob,  '3scale/backend/transactor/report_job'
      autoload :Status,     '3scale/backend/transactor/status'

      include Core::StorageKeyHelpers

      extend self

      def report(provider_key, transactions)
        notify(provider_key, 'transactions/create_multiple' => 1,
                             'transactions' => transactions.size)

        service_id = Service.load_id!(provider_key)
        Resque.enqueue(ReportJob, service_id, transactions)
      end

      VALIDATORS = [Validators::Key,
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
