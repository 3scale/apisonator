require 'influxdb'

module ThreeScale
  module Backend
    class StorageInfluxDB
      include Configurable

      SERIES_PREFIX = "service_"

      # @note There are plans to use a binary protocol to communicate
      #       with InfluxDB. We should track this and modify this class
      #       if needed. We should consider to extend the current
      #       InfluxDB::Client that consumes the HTTP API to allow persistent
      #       connections.
      def initialize(database, options = {})
        @client = InfluxDB::Client.new database, options
        @client.create_database(database) rescue nil
        @grouped_events = {}
      end

      # @note Now the influxdb is consuming the HTTP API and there is no problem
      #       unreferencing the client, but if we change this to a persistent
      #       connection, we should close the connection before unreference
      #       the var.
      def self.instance(reset = false)
        @instance = nil if reset
        @instance ||= new(
          configuration.influxdb.database,
          {
            host:     configuration.influxdb.hosts,
            username: configuration.influxdb.username,
            password: configuration.influxdb.password,
          }
        )

        @instance
      end

      # Adds an event to a batch.
      # Get conditions from the `key`, find an existing event with these
      # conditions and change its value. If it doesn't find an event,
      # prepares a new one.
      #
      # @param [String] key the composed key for redis with all event attributes.
      # @param [String] value the value.
      # @return [Array] the batch of events.
      def add_event(key, value)
        event = event_for_interval(key, value)
        name  = event.delete(:name)

        grouped_events[name] ||= []
        grouped_events[name] << event
      end

      attr_reader :grouped_events
      private :grouped_events

      # Sends batched events to influxdb.
      #
      # @return [true] True or raise and exception.
      #
      # @note: There is an easier and more efficient solution for this, but
      #        depends on this:
      #        https://github.com/influxdb/influxdb-ruby/issues/61
      #
      #        After that change, we won't need the group events hash.
      #        Instead, we could have an events array.
      def write_events
        grouped_events.each do |serie, events|
          @client.write_point(serie, events)
        end

        @grouped_events = {}

        true
      end

      # Finds an event for a service with service_id and
      # specific `conditions` and returns its value.
      #
      # @param [String, Integer] service_id the service id.
      # @param [String] period the period of time where find the event
      #                        (hour,day,week,month,year).
      # @param [Hash] conditions the conditions to find an event.
      # @return [Integer, nil] the event value or nil.
      def get(service_id, period, conditions = {})
        event = find_event(service_id, period, conditions)
        event[:value] if event
      end

      # Finds an event with specific `conditions`.
      #
      # @param [String, Integer] service_id the service id.
      # @param [String] period the period of time where find the event
      #                        (hour,day,week,month,year).
      # @param [Hash] conditions the conditions to find an event.
      # @return [Hash, nil] the hash with the event properties or nil.
      def find_event(service_id, period, conditions = {})
        conditions = optional_values.merge(conditions)

        if conditions[:time]
          time_on_period = conditions[:time].beginning_of_cycle(period.to_sym)
          conditions     = conditions.merge(time: time_on_period.to_i)
        end

        where_query = compose_where(conditions)
        serie       = serie_name(service_id, period)
        query       = "select * from #{serie} #{where_query} limit 1"

        begin
          events = @client.query(query)[serie]
        rescue InfluxDB::Error => exception
          if exception.message =~ /Couldn't look up columns/
            events = nil
          else
            raise exception
          end
        end

        events.first.symbolize_keys if events
      end

      # Drop all series (service events).
      #
      # @return [Boolean] True or raise an exception.
      #
      # @note: In the future, maybe they will add builtin support for this.
      # https://github.com/influxdb/influxdb/issues/448
      def drop_series
        list_query = "list series /#{SERIES_PREFIX}.*/"
        series     = @client.query(list_query)["list_series_result"]

        series.each do |serie|
          @client.query "drop series #{serie['name']}"
        end

        true
      end

      private

      def compose_where(conditions)
        return if conditions.empty?

        query = conditions.map do |key, value|
          if key == :time
            "#{key} > #{value}s and #{key} < #{value}s"
          else
            "#{key} = '#{value}'"
          end
        end.join(' and ')

        "where #{query}"
      end

      def event_for_interval(key, value)
        period, timestamp = extract_timestamp(key)
        time_on_period    = timestamp.beginning_of_cycle(period.to_sym)
        conditions        = event_metadata(key).merge(time: time_on_period)
        service_id        = conditions.delete(:service)
        event             = find_event(service_id, period, conditions)
        event           ||= conditions.merge(time: time_on_period.to_i)

        event.merge(value: value, name: serie_name(service_id, period))
      end

      def event_metadata(key)
        fields = extract_event_fields(key)

        fields.inject(optional_values) do |memo, (field, val)|
          if normalized_field = normalize_field(field)
            memo[normalized_field] = val.to_s
          end

          memo
        end
      end

      def optional_values
        {
          application: "0",
          user:        "0",
        }
      end

      def extract_timestamp(key)
        timeslot     = key.split('/').last
        period, time = timeslot.split(":")

        [period, Time.parse_to_utc(time)]
      end

      def extract_event_fields(key)
        key.scan(/(\w*):(\w*)/)
      end

      def normalize_field(field)
        {
          cinstance: :application,
          uinstance: :user,
          metric:    :metric,
          service:   :service,
        }[field.to_sym]
      end

      def serie_name(service_id, period)
        "#{SERIES_PREFIX}#{service_id}.#{period_name(period)}"
      end

      def period_name(period)
        {
          hour:  "1h",
          day:   "1d",
          week:  "1w",
          month: "1m",
          year:  "1y"
        }[period.to_sym]
      end
    end
  end
end
