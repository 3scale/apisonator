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

      def authorize(provider_key, params)
        notify(provider_key, 'transactions/authorize' => 1)

        service_id  = Service.load_id!(provider_key)
        application = Application.load!(service_id, params[:app_id])
        usage       = load_current_usage(application)
        
        status = Status.new(application, usage)

        status.reject_unless!(ApplicationKeyInvalid.new(params[:app_key])) do
          validate_application_key(application, params[:app_key])
        end
        status.reject_unless!(ApplicationNotActive.new) { application.active? }
        status.reject_unless!(LimitsExceeded.new) { validate_usage_limits(application, usage) }
        status
      end

      private
        
      def notify(provider_key, usage)
        Resque.enqueue(NotifyJob, provider_key, usage, encode_time(Time.now.getutc))
      end

      def encode_time(time)
        time.to_s
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

      def validate_usage_limits(application, usage)
        application.usage_limits.all? { |limit| limit.validate(usage) }
      end

      def validate_application_key(application, key)
        application.has_no_keys? || application.has_key?(key)
      end
      
      def storage
        Storage.instance
      end
    end
  end
end
