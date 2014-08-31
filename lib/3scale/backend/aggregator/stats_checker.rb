require_relative '../storage'
require_relative '../storage_influxdb'

module ThreeScale
  module Backend
    module Aggregator
      class StatsChecker

        attr_reader :service_id, :application_id, :metric_id

        # @param [String, Integer] service_id the service id.
        # @param [String, Integer] application_id the application id.
        # @param [String, Integer] metric_id the metric id.
        def initialize(service_id, application_id, metric_id)
          @service_id     = service_id.to_i
          @application_id = application_id
          @metric_id      = metric_id.to_i
        end

        # Get the stats values for a given `timestamp` and different
        # granularities on redis and influxdb.
        #
        # @param [Time] timestamp the timestamp in UTC.
        # @return [Hash] The hash with two keys (redis, influxdb) containing the
        #                different values per granularity.
        def check(timestamp)
          granularities = [:hour, :day, :week, :month, :year]
          results = { redis: {}, influxdb: {} }

          service_prefix            = StatsKeys.service_key_prefix(service_id)
          application_prefix        = StatsKeys.application_key_prefix(service_prefix, application_id)
          application_metric_prefix = StatsKeys.metric_key_prefix(application_prefix, metric_id)

          influxdb_conditions = {
            application: application_id,
            metric:      metric_id,
          }

          granularities.each do |gra|
            time = timestamp.beginning_of_cycle(gra).to_i
            influxdb_conditions.merge!(time: time)

            redis_key               = StatsKeys.counter_key(application_metric_prefix, gra, timestamp)
            results[:redis][gra]    = storage.get(redis_key).to_i
            results[:influxdb][gra] = storage_influxdb.get(service_id, gra, influxdb_conditions).to_i
          end

          results
        end

        private

        def storage
          Storage.instance
        end

        def storage_influxdb
          StorageInfluxDB.instance
        end
      end
    end
  end
end
