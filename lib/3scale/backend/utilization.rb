module ThreeScale
  module Backend
    class Utilization
      include Comparable

      attr_reader :metric_id, :period, :max_value, :current_value

      def initialize(limit, current_value)
        @metric_id = limit.metric_id
        @period = limit.period
        @max_value = limit.value
        @current_value = current_value
        @encoded = encoded(limit, current_value)
      end

      def ratio
        return 0 if max_value == 0 # Disabled metric
        current_value/max_value.to_f
      end

      # Returns in the format needed by the Alerts class.
      def to_s
        @encoded
      end

      def <=>(other)
        # Consider "disabled" the lowest ones
        if ratio == 0 && other.ratio == 0
          return max_value <=> other.max_value
        end

        ratio <=> other.ratio
      end

      # Note: this can return nil
      def self.max_in_all_metrics(service_id, app_id)
        application = Backend::Application.load!(service_id, app_id)

        usage = Usage.application_usage(application, Time.now.getutc)

        status = Transactor::Status.new(service_id: service_id,
                                        application: application,
                                        values: usage)

        # Preloads all the metric names to avoid fetching them one by one when
        # generating the usage reports
        application.load_metric_names

        max = status.application_usage_reports.map do |usage_report|
          Utilization.new(usage_report.usage_limit, usage_report.current_value)
        end.max

        # Avoid returning a utilization for disabled metrics
        max && max.max_value > 0 ? max : nil
      end

      # Note: this can return nil
      def self.max_in_metrics(service_id, app_id, metric_ids)
        application = Backend::Application.load!(service_id, app_id)

        limits = UsageLimit.load_for_affecting_metrics(
          service_id, application.plan_id, metric_ids
        )

        usage = Usage.application_usage_for_limits(application, Time.now.getutc, limits)

        max = limits.map do |limit|
          Utilization.new(limit, usage[limit.period][limit.metric_id])
        end.max

        # Avoid returning a utilization for disabled metrics
        max && max.max_value > 0 ? max : nil
      end

      private

      def encoded(limit, current_value)
        metric_name = Metric.load_name(limit.service_id, limit.metric_id)
        "#{metric_name} per #{limit.period}: #{current_value}/#{limit.value}"
      end
    end
  end
end
