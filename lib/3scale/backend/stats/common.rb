
module ThreeScale
  module Backend
    module Stats
      module Common
        private

       # Method that generates a hash having correspondence between index and
        # granularity name and viceversa. Maybe split it into two different
        # hashes???? That would make 4 constants to be created
        #TODO maybe move this to another place??
        def self.get_indexed_granularities(granularities)
          res = {}
          granularities.each_with_index do |grn, idx|
            res[grn.to_sym] = idx
            res[idx] = grn.to_sym
          end
          res
        end

        public

        SERVICE_GRANULARITIES =
        [:eternity, :month, :week, :day, :hour].map do |g|
          Period[g]
        end.freeze

        # For applications and users
        EXPANDED_GRANULARITIES = (SERVICE_GRANULARITIES + [Period[:year], Period[:minute]]).freeze

        GRANULARITY_EXPIRATION_TIME = { Period[:minute] => 180 }.freeze
        private_constant :GRANULARITY_EXPIRATION_TIME

        #TODO maybe could be a good idea to generate this from the Period::Symbols
        #array in order to have a match between index order and granularity order???
        #or use Period::ALL and substrct specific periods from another array?
        PERMANENT_SERVICE_GRANULARITIES = (SERVICE_GRANULARITIES - GRANULARITY_EXPIRATION_TIME.keys).freeze
        PERMANENT_EXPANDED_GRANULARITIES = (EXPANDED_GRANULARITIES - GRANULARITY_EXPIRATION_TIME.keys).freeze

        #TODO maybe move this to another place??
        PERMANENT_SVC_GRN_IDX = Stats::Common::get_indexed_granularities(PERMANENT_SERVICE_GRANULARITIES).freeze
        PERMANENT_EXP_GRN_IDX = Stats::Common::get_indexed_granularities(PERMANENT_EXPANDED_GRANULARITIES).freeze

        # We are not going to send metrics with granularity 'eternity' or
        # 'week' to Kinesis, so there is no point in storing them in Redis
        # buckets.
        EXCLUDED_FOR_BUCKETS = [Period[:eternity], Period[:week]].freeze

        # Return an array of granularities given a metric_type
        def self.granularities(metric_type)
          metric_type == :service ? SERVICE_GRANULARITIES : EXPANDED_GRANULARITIES
        end

        def self.expire_time_for_granularity(granularity)
          GRANULARITY_EXPIRATION_TIME[granularity]
        end

      end
    end
  end
end
