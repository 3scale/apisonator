require 'influxdb'

module ThreeScale
  module Backend
    class StorageInfluxDB
      include Configurable

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
            host:          configuration.influxdb.hosts,
            username:      configuration.influxdb.username,
            password:      configuration.influxdb.password,
            retry:         configuration.influxdb.retry,
            write_timeout: configuration.influxdb.write_timeout,
            read_timeout:  configuration.influxdb.read_timeout,
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
        event  = event_for_interval(key, value)
        status = event[:sequence_number] ? :new : :existing
        name   = event.delete(:serie_name)

        grouped_events[name] ||= { new: [], existing: [] }
        grouped_events[name][status] << event

        event
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
          events.each_value do |evts|
            @client.write_point(serie, evts) unless evts.empty?
          end
        end

        @grouped_events = {}

        true
      end

      # Finds an event and returns its value.
      #
      # @param [String, Integer] service_id the service id.
      # @param [String, Integer] metric_id the metric id.
      # @param [String] period the period of time where find the event
      #                        (hour,day,week,month,year).
      # @param [Time] time the timestamp of the event.
      # @param [Hash] conditions the conditions to find an event.
      # @return [Integer, nil] the event value or nil.
      def get(service_id, metric_id, period, time, conditions = {})
        event = find_event(service_id, metric_id, period, time, conditions)
        event[:value] if event
      end

      # Finds an event.
      #
      # @param [String, Integer] service_id the service id.
      # @param [String, Integer] metric_id the metric id.
      # @param [String] period the period of time where find the event
      #                        (hour,day,week,month,year).
      # @param [Time] time the timestamp of the event.
      # @param [Hash] conditions the conditions to find an event.
      # @return [Hash, nil] the hash with the event properties or nil.
      def find_event(service_id, metric_id, period, time, conditions = {})
        time_on_period = time.beginning_of_cycle(period.to_sym).to_i
        serie          = serie_name(service_id, metric_id, period, conditions)

        find_event_by_serie_name(serie, time_on_period, conditions)
      end

      # Drop all series.
      #
      # @return [Boolean] True or raise an exception.
      #
      # @note: In the future, maybe they will add builtin support for this.
      # https://github.com/influxdb/influxdb/issues/448
      def drop_all_series
        list_query = "list series"
        series     = @client.query(list_query)["list_series_result"]

        series.each do |serie|
          @client.query "drop series #{serie['name']}"
        end

        true
      end

      private

      def serie_name(service_id, metric_id, period, metadata)
        attrs  = attrs_for_serie_name(service_id, metric_id)
        suffix = period_name(period)
        prefix = attrs.inject("") do |acc, (k,v)|
          acc.tap do |obj|
            obj << "_" unless obj.empty?
            obj << [k,v].join("_")
          end
        end
        prefix << "_applications" if metadata[:application]
        prefix << "_end_users" if metadata[:user]

        "#{prefix}.#{suffix}"
      end

      def attrs_for_serie_name(service_id, metric_id)
        {
          service: service_id,
          metric:  metric_id,
        }
      end

      def event_for_interval(key, value)
        period, timestamp = extract_timestamp(key)
        metadata          = event_metadata(key)
        service_id        = metadata.delete(:service)
        metric_id         = metadata.delete(:metric)

        event             = find_event(service_id, metric_id, period, timestamp, metadata)
        event           ||= new_event(service_id, metric_id, period, timestamp, metadata)

        event.merge!(value: value)
      end

      # TODO: Add a method to filter/validate metadata?

      def new_event(service_id, metric_id, period, time, metadata)
        time_on_period = time.beginning_of_cycle(period.to_sym).to_i
        serie          = serie_name(service_id, metric_id, period, metadata)

        { time: time_on_period, serie_name: serie }.merge!(metadata)
      end

      def event_metadata(key)
        fields = extract_event_fields(key)

        fields.inject({}) do |memo, (field, val)|
          if normalized_field = normalize_field(field)
            memo[normalized_field] = val.to_s
          end

          memo
        end
      end

      def query(serie_name, query)
        @client.query(query)[serie_name] || []
      rescue InfluxDB::Error => exception
        if exception.message =~ /Couldn\'t find series/
          []
        else
          raise exception
        end
      end

      def compose_query(serie_name, time, metadata, limit = nil)
        where = "WHERE time > #{time}s and time < #{time}s"
        where = metadata.inject(where) do |acc, (field, val)|
          acc << " AND "
          acc << "#{field} = '#{val}'"

          acc
        end
        limit_statement = limit ? "LIMIT #{limit}" : ""
        "SELECT * FROM #{serie_name} #{where} #{limit_statement}"
      end

      def find_event_by_serie_name(serie_name, time, metadata)
        query_str = compose_query(serie_name, time, metadata, 1)
        event     = query(serie_name, query_str).first

        if event
          event.symbolize_keys.merge!(serie_name: serie_name)
        end
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
