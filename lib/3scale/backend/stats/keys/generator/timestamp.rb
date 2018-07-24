module ThreeScale
  module Backend
    module Stats
      module Keys
        module Generator
          class Timestamp
            private

            attr_accessor :granularity_idx, :granularity_name

            def initialize(granularity_idx, granularity_name)
              @granularity_idx = granularity_idx # The granularity index of this timestamp
              @granularity_name = granularity_name
            end

            def get_granularity_limits(limits)
              [limits[0].granularity, limits[1].granularity]
            end

            def get_time_limits(limits)
              Range.new(limits[0].ts, limits[1].ts)
            end

            # There are five cases to determine from what timestamp to what timestamp should we iterate
            # in the current granularity being processed:
            # 1 - If there are no limits specified we should process all timestamps contained
            #     in the service_context from and to fields
            # 2 - If there are limits, if the granularities specified in the from and to
            #     match the current granularity being processed, then we honor the specified timestamp limits
            #     in the limits object
            # 3 - If there are limits, if the granularity specified in the from limit matches the
            #     granularity being processed, and the granularity specified in the to limit does not
            #     we iterate from the timestamp specified in the from limit, to the timestamp specified
            #     in the service_context
            # 4 - If there are limits, if the granularity specified in the from limit does not match the
            #     granularity being processed, and the granularity specified in the to limit matches
            #     we iterate from the timestamp specified in the service_context, to the timestamp specified
            #     in the to limit
            # 5 - If there are limits, if neither of the granularities specified in the from and to limits match
            #     the granularity being processed, we iterate from the timestamp
            #     to the timestamp specified in the service_context
            def get_timestamp_limits(service_context, limits)
              return service_context.from, service_context.to if limits.nil?

              grn_start_lim, grn_end_lim = get_granularity_limits(limits)
              ts_idx_lim = get_time_limits(limits)

              from = service_context.from
              to = service_context.to

              # Only use limit from partition limits when partition index generator is current generator
              from = ts_idx_lim.first if grn_start_lim == granularity_idx
              to = ts_idx_lim.last if grn_end_lim == granularity_idx
              [from, to]
            end

            def get_time_generator(service_context, limits)
              Enumerator.new do |yielder|
                from, to = get_timestamp_limits(service_context, limits).map do |ts|
                  ## A problem has been detected here in this two lines. It seems it is caching
                  ## the @timestamp instance attribute for the Period[:month] even though
                  ## we recreate the period. It caches the entire Period instance
                  ## based on the start time, so because in this case both period
                  ## objects have the same start time, it retrieves
                  ## the object from the period cache with the same timestamp.
                  ## Also, it is not possible to modify the timestamp of an existing
                  ## period because it is a private field.
                  start_ts = ThreeScale::Backend::Period[granularity_name].new(Time.at(ts).utc).start
                  period = ThreeScale::Backend::Period[granularity_name].new(start_ts)
                end
                while from.start <= to.start
                  yielder << [generate_timestamp_key(from), from.start.to_i]
                  next_ts = from.finish
                  from = ThreeScale::Backend::Period[granularity_name].new(next_ts)
                end
              end
            end

            def generate_timestamp_key(period)
              granularity = period.granularity
              key = "#{granularity}"
              if granularity.to_sym != :eternity
                key += ":#{period.start.to_compact_s}"
              end
              key
            end

            def self.get_granularity_limits(granularity_list, limits)
              # Array range goes from A to B, (B - A + 1) elements
              return Range.new(0, granularity_list.size - 1) if limits.nil?
              limit_start = limits[0].granularity || 0
              limit_end = limits[1].granularity || 0
              Range.new(limit_start, limit_end)
            end

            def self.granularity_to_period(grn_arr)
              grn_arr.each_with_index.map do |name, idx|
                Timestamp.new(idx, name.to_sym)
              end
            end

            SERVICE_TIMESTAMPS = granularity_to_period(Stats::Common::PERMANENT_SERVICE_GRANULARITIES)
            EXPANDED_TIMESTAMPS = granularity_to_period(Stats::Common::PERMANENT_EXPANDED_GRANULARITIES)

            def self.timestamps(metric_type)
              metric_type.to_sym == :service ? SERVICE_TIMESTAMPS : EXPANDED_TIMESTAMPS
            end

            def self.yield_timestamp(service_context, limits, yielder, period)
              if period.send(:granularity_name) == :eternity
                yielder << ['eternity', 0]
              else
                period.send(:get_time_generator, service_context, limits).each do |datetime_key, ts|
                  yielder << [datetime_key, period.send(:granularity_idx), ts]
                end
              end
            end

            public

            #metric_type is 'service', 'application' or 'user'. Could be called key_type???
            def self.get_time_generator(service_context, limits, metric_type)
              Enumerator.new do |yielder|
                grn_idx_lim = get_granularity_limits(timestamps(metric_type), limits)
                timestamps(metric_type)[grn_idx_lim].each do |period|
                  yield_timestamp(service_context, limits, yielder, period)
                end
              end
            end
          end
        end
      end
    end
  end
end
