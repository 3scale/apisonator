module ThreeScale
  module Backend
    module Stats
      module Keys
        module Generator
          class Timestamp
            private
            def get_metric_type_granularity_limits(periods)
              # Array range goes from A to B, (B - A + 1) elements
              return Range.new(0, periods.size - 1) if index_limits.nil?
              limit_start = index_limits[0].granularity || 0
              limit_end = index_limits[1].granularity || 0
              Range.new(limit_start, limit_end)
            end

            def get_granularity_limits
              [index_limits[0].granularity, index_limits[1].granularity]
            end

            def get_time_limits
              Range.new(index_limits[0].ts, index_limits[1].ts)
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
            def get_timestamp_limits(granularity_idx)
              return service_context.from, service_context.to if index_limits.nil?

              grn_start_lim, grn_end_lim = get_granularity_limits
              ts_idx_lim = get_time_limits

              from = service_context.from
              to = service_context.to

              # Only use limit from partition limits when partition index generator is current generator
              from = ts_idx_lim.first if grn_start_lim == granularity_idx
              to = ts_idx_lim.last if grn_end_lim == granularity_idx
              [from, to]
            end

            def generate_timestamp_key(period)
              granularity = period.granularity
              key = "#{granularity}"
              if granularity.to_sym != :eternity
                key += ":#{period.start.to_compact_s}"
              end
              key
            end

            def get_datetime_generator_for_granularity(granularity_name, granularity_index)
              Enumerator.new do |yielder|
                from, to = get_timestamp_limits(granularity_index).map do |ts|
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

            def yield_timestamp(datetime_gen, yielder, granularity_name, granularity_idx)
              if granularity_name == :eternity
                yielder << ['eternity', 0]
              else
                datetime_gen.each do |datetime_key, ts|
                  yielder << [datetime_key, granularity_idx, ts]
                end
              end
            end

            attr_reader :service_context, :index_limits, :metric_type

            public

            def initialize(service_context, index_limits, metric_type)
              @service_context = service_context
              @index_limits = index_limits
              @metric_type = metric_type
            end

            def get_time_generator
              Enumerator.new do |yielder|
                periods = metric_type.to_sym == :service ? Stats::Common::PERMANENT_SERVICE_GRANULARITIES : Stats::Common::PERMANENT_EXPANDED_GRANULARITIES
                grn_idx_lim = get_metric_type_granularity_limits(periods)
                periods[grn_idx_lim].each_with_index do |period, relative_index|
                  # This is done because we are iterating a range and the indexes have moved
                  # This works because ranges are ascending always
                  grn_index = relative_index + grn_idx_lim.first
                  datetime_gen = get_datetime_generator_for_granularity(period.to_sym, grn_index)
                  yield_timestamp(datetime_gen, yielder, period.to_sym, grn_index)
                end
              end
            end
          end
        end
      end
    end
  end
end
