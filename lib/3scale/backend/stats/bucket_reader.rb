module ThreeScale
  module Backend
    module Stats

      # This class allows us to read the buckets that we are creating in Redis
      # to store the stats keys that change. It also allows us to keep track of
      # the ones that are pending to be read.
      class BucketReader

        # This private nested class allows us to isolate accesses to Redis.
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

          private

          attr_reader :storage
        end
        private_constant :LatestBucketReadMarker

        # Before we read and mark a bucket as read, we need to make sure that
        # it will not receive more events. Otherwise, there is the risk that
        # we will miss some events.
        # Buckets are created every 'bucket_create_interval' seconds, it is one
        # of the parameters that 'initialize' receives. We should be able to
        # read any bucket identified with a timestamp ts, where
        # ts < Time.now - bucket_create_interval. However, in order to be sure
        # that we will not miss any events, we are going to define a constant
        # that will define some backup time.
        BACKUP_SECONDS_READ_BUCKET = 10
        private_constant :BACKUP_SECONDS_READ_BUCKET

        InvalidInterval = Class.new(ThreeScale::Backend::Error)

        def initialize(bucket_create_interval, bucket_storage)
          # This is needed because ThreeScale::Backend::TimeHacks.beginning_of_bucket
          if 60%bucket_create_interval != 0 || bucket_create_interval <= 0
            raise InvalidInterval, 'Bucket create interval needs to divide 60'
          end

          @bucket_create_interval = bucket_create_interval
          @bucket_storage = bucket_storage
          @latest_bucket_read_marker = LatestBucketReadMarker.new(bucket_storage.storage)
        end

        # Returns the pending events and the bucket of the most recent of the
        # events sent. This allows the caller to call latest_bucket_read= when
        # it has processed all the events.
        def pending_events_in_buckets(end_time_utc: Time.now.utc, max_buckets: nil)
          buckets = if max_buckets
                      pending_buckets(end_time_utc).take(max_buckets)
                    else
                      pending_buckets(end_time_utc).to_a
                    end

          events = bucket_storage.buckets_content_with_values(buckets)
          { events: events, latest_bucket: buckets.last }
        end

        def latest_bucket_read=(latest_bucket_read)
          latest_bucket_read_marker.latest_bucket_read = latest_bucket_read
        end

        private

        attr_reader :bucket_create_interval, :bucket_storage, :latest_bucket_read_marker

        def pending_buckets(end_time_utc = Time.now.utc)
          latest_bucket_read = latest_bucket_read_marker.latest_bucket_read
          start_time = unless latest_bucket_read.nil?
                         bucket_to_time(latest_bucket_read) + bucket_create_interval
                       end
          end_time = end_time_with_backup(end_time_utc)
          stored_buckets(start_time, end_time)
        end

        def end_time_with_backup(end_time_utc)
          [end_time_utc, Time.now.utc - bucket_create_interval - BACKUP_SECONDS_READ_BUCKET].min
        end

        def stored_buckets(start_time_utc, end_time_utc)
          range = { }
          range[:first] = time_to_bucket_name(start_time_utc) if start_time_utc
          range[:last] = time_to_bucket_name(end_time_utc)
          bucket_storage.buckets(range)
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
