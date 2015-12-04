module ThreeScale
  module Backend
    module Stats

      # This class allows us to read the buckets that we are creating in Redis
      # to store the stats keys that change. The buckets are created and
      # updated in ThreeScale::Backend::Stats:Aggregator.
      class BucketReader

        # This private nested class allows us to isolate accesses to Redis
        class LatestBucketReadMarker
          LATEST_BUCKET_READ_KEY = 'send_to_kinesis:latest_bucket_read'
          private_constant :LATEST_BUCKET_READ_KEY

          def initialize(storage)
            @storage = storage
          end

          def latest_bucket_read=(latest_bucket_read)
            storage.set(LATEST_BUCKET_READ_KEY, latest_bucket_read)
          end

          def latest_bucket_read
            storage.get(LATEST_BUCKET_READ_KEY)
          end

          def all_buckets
            # It would be nice to get rid of this coupling.
            # Consider refactoring the 'Info' module.
            Info.pending_buckets
          end

          private

          attr_reader :storage
        end
        private_constant :LatestBucketReadMarker

        InvalidInterval = Class.new(ThreeScale::Backend::Error)

        def initialize(bucket_create_interval, storage)
          # This is needed because ThreeScale::Backend::TimeHacks.beginning_of_bucket
          if 60%bucket_create_interval != 0 || bucket_create_interval <= 0
            raise InvalidInterval, 'Bucket create interval needs to divide 60'
          end

          @bucket_create_interval = bucket_create_interval
          @latest_bucket_read_marker = LatestBucketReadMarker.new(storage)
        end

        def pending_buckets(end_time_utc = Time.now.utc)
          latest_bucket_read = latest_bucket_read_marker.latest_bucket_read
          return latest_bucket_read_marker.all_buckets if latest_bucket_read.nil?

          start_time_utc = bucket_to_time(latest_bucket_read) + bucket_create_interval
          buckets(start_time_utc, end_time_utc)
        end

        private
        attr_reader :bucket_create_interval, :latest_bucket_read_marker

        def buckets(start_time_utc, end_time_utc)
          # The number of buckets can be very large depending on the start
          # date. For that reason, we return an enumerator.
          Enumerator.new do |y|
            (start_time_utc.to_i..end_time_utc.to_i).step(@bucket_create_interval) do |sec|
              y << time_to_bucket_name(Time.at(sec).utc)
            end
          end
        end

        def time_to_bucket_name(time_utc)
          # We know that the names of the buckets follow the following pattern:
          # they are a timestamp with format YYYYmmddHHMMSS
          time_utc.strftime('%Y%m%d%H%M%S')
        end

        def bucket_to_time(bucket_name)
          DateTime.parse(bucket_name).to_time.utc
        end
      end
    end
  end
end
