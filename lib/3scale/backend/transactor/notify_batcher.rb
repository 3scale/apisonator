module ThreeScale
  module Backend
    module Transactor
      module NotifyBatcher
        include Resque::Helpers
        include Backend::Configurable
        
        def key_for_notifications_batch
          "notify/aggregator/batch"
        end
        
        def process_batch(num_elements)
          tt = Time.now
          all = Hash.new
          list = storage.lrange(key_for_notifications_batch,0,num_elements-1)
          storage.ltrim(key_for_notifications_batch,num_elements,-1)
          
          list.each do |item|
            obj = decode(item)
            bucket_key = "#{obj['provider_key']}-#{tt.to_s}"

            all[bucket_key] = {"provider_key" => obj["provider_key"], "time" => obj["time"], "usage" => {}} if all[bucket_key].nil?

            obj["usage"].each do |metric_name, value|
              value = value.to_i
              all[bucket_key]["usage"][metric_name] ||= 0
              all[bucket_key]["usage"][metric_name] += value
            end
          end

          all.each do |k, v|
            Resque.enqueue(NotifyJob, v["provider_key"], v["usage"], encode_time(v["time"]), tt.to_f)
          end
        end
        
        def notify_batch(provider_key, usage)
          ## remove the seconds, so that all are stored in the same bucket, aggregation is done at the minute level
          tt = Time.now.getutc
          tt = tt-tt.sec

          encoded = Yajl::Encoder.encode({:provider_key => provider_key, :usage => usage, :time => encode_time(tt)})
          num_elements = storage.rpush(key_for_notifications_batch, encoded)

          ## HACK: TO REMOVE, this is so that tests pass right aways, a batch of 1
          configuration.notification_batch = 1

          if (num_elements  % configuration.notification_batch) == 0
            ## we have already a full batch, we have to create the NotifyJobs for the backend 
            process_batch(num_elements)
          end
        end
      end
    end
  end
end