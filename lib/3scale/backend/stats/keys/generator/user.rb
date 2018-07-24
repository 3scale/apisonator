# Create a user keys generator
module ThreeScale
  module Backend
    module Stats
      module Keys
        module Generator
          class User
            # A index_limits is an array of two elements where each
            # element is: {"key_type":0,"metric":0,"app":0,"users":null,"granularity":0,"ts":0}
            def initialize(service_context, index_limits)
              @service_context = service_context
              @index_limits = index_limits
              @users = @service_context.users || []
              @metrics = @service_context.metrics || []
            end

            def get_generator
              #TODO refactor this
              Enumerator.new do |yielder|
                usr_idx_lim = get_user_index_limits
                mtr_idx_lim = get_metric_index_limits
                datetime_gen = Timestamp.new(service_context, index_limits, :user).get_time_generator
                users[usr_idx_lim].each_with_index do |username, usr_idx|
                  metrics[mtr_idx_lim].each_with_index do |mtr_id, m_idx|
                    datetime_gen.each do |datetime_key, granularity_index, ts|
                      index_key = Index.new(user: usr_idx, metric: m_idx, granularity: granularity_index, ts: ts) #TODO missing key_type??
                      stats_key = generate_stats_key(service_context.service_id, username, mtr_id, datetime_key)
                      yielder << IndexedKey.new(idx, stats_key)
                    end
                end
              end
            end

            private

            attr_accessor :service_context, :index_limits, :users, :metrics

            def get_user_index_limits
              return Range.new(0, users.size -1) if index_limits.nil?
              limit_start = index_limits[0].user || 0
              limit_end = index_limits[1].user || 0
              Range.new(limit_start, limit_end)
            end

            def get_metric_index_limits
              return Range.new(0, metrics.size - 1) if index_limits.nil?
              limit_start = index_limits[0].metric || 0
              limit_end = index_limits[1].metric || 0
              Range.new(limit_start, limit_end)
            end

            def generate_stats_key(service_id, user_id, metric_id, datetime)
              Keys::user_usage_value_key(service_id, user_id, metric_id, datetime)
            end
          end
        end
      end
    end
  end
end
