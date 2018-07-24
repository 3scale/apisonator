
module ThreeScale
  module Backend
    module Stats
      module Common
        SERVICE_GRANULARITIES =
        [:eternity, :month, :week, :day, :hour].map do |g|
          Period[g]
        end.freeze

        # For applications and users
        EXPANDED_GRANULARITIES = (SERVICE_GRANULARITIES + [Period[:year], Period[:minute]]).freeze

        GRANULARITY_EXPIRATION_TIME = { Period[:minute] => 180 }.freeze
        private_constant :GRANULARITY_EXPIRATION_TIME

        PERMANENT_SERVICE_GRANULARITIES = SERVICE_GRANULARITIES - GRANULARITY_EXPIRATION_TIME.keys
        PERMANENT_EXPANDED_GRANULARITIES = EXPANDED_GRANULARITIES - GRANULARITY_EXPIRATION_TIME.keys

        # We are not going to send metrics with granularity 'eternity' or
        # 'week' to Kinesis, so there is no point in storing them in Redis
        # buckets.
        EXCLUDED_FOR_BUCKETS = [Period[:eternity], Period[:week]].freeze


      end
    end
  end
end
