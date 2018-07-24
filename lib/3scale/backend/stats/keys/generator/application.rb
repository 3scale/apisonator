module ThreeScale
  module Backend
    module Stats
      module Keys
        module Generator
          class Application
            def initialize(service_context, index_limits)
              @service_context = service_context
              @index_limits = index_limits
              @applications = @service_context.applications || []
              @metrics = @service_context.metrics || []
            end

            def get_generator
              Enumerator.new do |yielder|
                app_idx_lim = get_application_index_limits
                mtr_idx_lim = get_metric_index_limits
                datetime_gen = Timestamp.new(service_context, index_limits, :application).get_time_generator
                applications[app_idx_lim].each_with_index do |app_id, app_range_idx|
                  metrics[mtr_idx_lim].each_with_index do |metric_id, metric_range_idx|
                    datetime_gen.each do |datetime_key, granularity_idx, ts|
                      idx = Index.new(app: app_range_idx, metric: metric_range_idx, granularity: granularity_idx, ts: ts)
                      stats_key = generate_stats_key(service_context.service_id, app_id, metric_id, datetime_key)
                      yielder << IndexedKey.new(idx, stats_key)
                    end
                  end
                end
              end
            end

            private

            attr_accessor :service_context, :index_limits, :applications, :metrics

            def get_application_index_limits
              # Array range goes from A to B, (B - A + 1) elements
              return Range.new(0, metrics.size - 1) if index_limits.nil?
              limit_start = index_limits[0].application || 0
              limit_end = index_limits[1].application || 0
              Range.new(limit_start, limit_end)
            end

            def get_metric_index_limits
              return Range.new(0, metrics.size - 1) if index_limits.nil?
              limit_start = index_limits[0].metric || 0
              limit_end = index_limits[1].metric || 0
              Range.new(limit_start, limit_end)
            end

            def generate_stats_key(service_id, user_id, metric_id, datetime)
              Keys::application_usage_value_key(service_id, application_id, metric_id, datetime)
            end
          end
        end
      end
    end
  end
end

