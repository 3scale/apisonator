module ThreeScale
  module Backend
    module Stats
      module Keys
        module Generator
          class Metric
            def initialize(service_context, limits)
              @service_context = service_context
              @index_limits = index_limits
              @metrics = @service_context.metrics || []
            end

            def get_generator
              Enumerator.new do |yielder|
                mtr_idx_lim = get_metric_index_limits
                datetime_gen = Timestamp.new(service_context, index_limits, :service).get_time_generator
                metrics[mtr_idx_lim].each_with_index do |mtr_id, mtr_idx|
                  datetime_gen.each do |datetime_key, granularity_idx, ts|
                    idx = Index.new(metric: mtr_id, granularity: granularity_idx, ts: ts)
                    stats_key = generate_stats_key(service_context.service_id, mtr_id, datetime_key)
                    yielder << IndexedKey.new(idx, stats_key)
                  end
                end
              end
            end

            private

            attr_accessor :service_context, :index_limits, :metrics

            def get_metric_index_limits
              # Array range goes from A to B, (B - A + 1) elements
              #return 0, metrics.size - 1
              #Range.new()index_limits[0..1].map(&:metric).map { |x| x || 0 }
              return Range.new(0, metrics.size - 1) if index_limits.nil?
              limit_start = index_limits[0].metric || 0
              limit_end = index_limits[1].metric || 0
              Range.new(limit_start, limit_end)
            end

            def generate_stats_key(service_id, metric_id, datetime)
              Keys::metric_usage_value_key(service_id, metric_id, datetime)
            end
          end
        end
      end
    end
  end
end
