require 'mongo'

module ThreeScale
  module Backend
    class StorageMongo
      include Configurable
      include Mongo

      DEFAULT_SERVER   = "localhost:27017"
      DEFAULT_DATABASE = "backend_test"

      def initialize(options = {})
        if ENV['MONGODB_URI']
          @client = MongoClient.from_uri
          @db = @client.db
        else
          servers = options[:servers] || Array(DEFAULT_SERVER)
          db = options[:db] || DEFAULT_DATABASE
          if servers.size > 1
            @client  = MongoShardedClient.new(servers, options[:db_options])
            @db      = @client.db(db)
          else
            server, port = servers.first.split(":")
            @client = MongoClient.new(server, port)
            @db     = @client.db(db)
          end
        end
      end

      # Returns a shared instance of the storage. If there is no instance yet,
      # creates one first. If you want to always create a fresh instance, set the
      # +reset+ parameter to true.
      def self.instance(reset = false)
        @@instance = nil if reset
        @@instance ||= new(
          servers:    configuration.mongo.servers,
          db:         configuration.mongo.db,
          db_options: configuration.mongo.db_options,
        )

        @@instance
      end

      def self.reset_to_nil!
        @@instance = nil
      end

      def client
        @client
      end

      def clear_collections
        collections = @db.collections.select { |c| c.name !~ /^system/ }
        collections.map { |c| c.drop }
      end

      def batch
        @batch ||= {}
      end

      def get(granularity, timestamp, conditions)
        beg = if [:hour, :minute, :day].include?(granularity)
                :day
              else
                granularity
              end

        conditions.merge!(t: timestamp.beginning_of_cycle(beg))
        collection = collection_for_interval(granularity)
        doc        = @db.collection(collection).find_one(search_query(conditions))

        if doc
          field = reduce_field_name(granularity).to_s
          case granularity
          when :hour
            doc[field][("%.2d" % timestamp.hour)]
          when :minute
            doc[field][("%.2d" % timestamp.hour)][("%.2d" % timestamp.min)]
          when :day
            doc[field]
          else
            field = reduce_field_name("value").to_s
            doc[field]
          end
        end
      end

      def prepare_batch(key, value)
        interval_type, interval_timestamp = extract_interval_data(key)
        collection_name                   = collection_for_interval(interval_type)

        batch[collection_name] ||= {}

        document = doc_for_interval(
          interval_type,
          collection_name,
          key,
          interval_timestamp,
          value
        )

        batch[collection_name][key] = document
      end

      def execute_batch
        batch.map do |collection, documents|
          documents.map do |_, doc|
            @db.collection(collection).update(
              search_query(doc[:metadata]),
              {
                "$set" => doc[:values],
              },
              upsert: true
            )
          end
        end
        clean_batch
      end

      private

      def doc_for_interval(interval_type, collection, key, timestamp, value)
        fields   = extract_doc_fields(key)
        document = batch[collection][key] || initial_doc(timestamp, fields)
        time_key = key_for_time_field(interval_type, timestamp)

        document[:values][time_key] = value
        document
      end

      def extract_interval_data(key)
        type, timestamp = key.split("/").last.split(":")
        timestamp ||= Time.utc(1970, 1, 1).to_compact_s
        timestamp << "0" unless timestamp.size % 2 == 0

        [type, timestamp]
      end

      def collection_for_interval(interval_type)
        {
          day:      :daily,
          hour:     :daily,
          minute:   :daily,
          year:     :yearly,
          month:    :monthly,
          eternity: :eternity,
        }[interval_type.to_sym]
      end

      def key_for_time_field(interval_type, timestamp)
        day_timestamp     = timestamp[0..7]
        hour_key, min_key = extract_hour_and_min(timestamp, day_timestamp)

        case interval_type
        when "day"
          reduce_field_name('day')
        when "hour"
          "#{reduce_field_name('hour')}.%.2d" % hour_key.to_i
        when "minute"
          "#{reduce_field_name('minute')}.%.2d.%.2d" % [hour_key.to_i, min_key.to_i]
        else
          reduce_field_name('value')
        end
      end

      def search_query(metadata)
        [:application, :end_user, :metric, :service, :timestamp].map do |field|
          metadata[reduce_field_name(field)] ||= nil
        end
        metadata
      end

      def extract_doc_fields(key)
        key.scan(/(\w*):(\w*)/)
      end

      def extract_hour_and_min(timestamp, day_interval)
        hour_and_min = timestamp.sub(day_interval, '')
        hour_and_min.scan(/../)
      end

      def initial_doc(timestamp, fields)
        parsed_timestamp = Time.parse_to_utc(timestamp).beginning_of_cycle(:day)
        doc = {
          metadata: { t: parsed_timestamp },
          values:   {},
        }
        fields.inject(doc) do |memo, (key, value)|
          field = metadata_field(key)
          memo[:metadata][reduce_field_name(field)] = value if field

          memo
        end
      end

      def reduce_field_name(field)
        {
          application: :a,
          end_user:    :e,
          metric:      :m,
          service:     :s,
          timestamp:   :t,
          day:         :day,
          minute:      :min,
          hour:        :hr,
          value:       :val,
        }[field.to_sym]
      end

      def metadata_field(field)
        {
          cinstance: :application,
          uinstance: :end_user,
          metric:    :metric,
          service:   :service,
        }[field.to_sym]
      end

      def clean_batch
        @batch = {}
      end
    end
  end
end
