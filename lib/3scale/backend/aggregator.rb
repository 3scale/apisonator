require 'json'
require '3scale/backend'
require '3scale/backend/cache'
require '3scale/backend/alerts'
require '3scale/backend/errors'
require '3scale/backend/aggregator/stats_batcher'
require '3scale/backend/aggregator/stats_job'


module ThreeScale
  module Backend
    module Aggregator
      include Core::StorageKeyHelpers
      include Backend::Cache
      include Backend::Alerts
      include Configurable
      include StatsBatcher
      extend self
    
      def aggregate_all(transactions)
        applications = Hash.new
        users = Hash.new
        
        ## this is just a temporary switch to be able to enable disable reporting to cassandra
        ## you can active it or deactivated: storage.set("cassandra_enabled","1") / storage.del("cassandra_enabled")
        
        @cass_enabled = cassandra_enabled?
        
        if @cass_enabled 
          bucket = Time.now.utc.beginning_of_bucket(Aggregator.stats_bucket_size).to_not_compact_s
          @@current_bucket ||= bucket
          
          if @@current_bucket == bucket 
            schedule_cassandra_job = false
          else 
            schedule_cassandra_job = true
            @@current_bucket = bucket
          end
        end
                
        transactions.each_slice(PIPELINED_SLICE_SIZE) do |slice|
           
          @keys_doing_set_op = []
           
          val = storage.pipelined do
            slice.each do |transaction|
              key = transaction[:application_id]
             
              ## the key must be application+user if users exists since this is the lowest
              ## granularity.
              ## applications contains the list of application, or application+users that need to be limit checked
              applications[key] = {:application_id => transaction[:application_id], :service_id => transaction[:service_id]}
              ## who puts service_id here? it turns out is the transactor.report_enqueue
              if transaction[:service_id].nil?
              end

              unless (transaction[:user_id].nil?)
                key = transaction[:user_id]
                users[key] = {:service_id => transaction[:service_id], :user_id => transaction[:user_id]}
              end
    
              aggregate(transaction)
            end
          end
          
          ## here the pipelined redis increments have been sent
          ## now we have to send the cassandra ones
          
          ## FIXME we had set operations :-/ This will only work when the key is on redis, it will not be true in the future
          ## not live keys (stats only) will only be on cassandra. Will require fix, or limit the usage of #set. In addition,
          ## set operations cannot coexist on increments on the same metric in the same pipeline. It has to be a check that
          ## set operations cannot be batched, only one transaction.
          
          if @cass_enabled && @keys_doing_set_op.size>0
            
            @keys_doing_set_op.each do |item|
              key, value = item
              
              old_value, tmp = storage.pipelined do
                storage.get(key)
                storage.set(key, value)
              end
                          
              storage.pipelined do
                storage.incrby("#{@@current_bucket}:#{key}", -old_value.to_i)
                storage.incrby("#{@@current_bucket}:#{key}", value)
              end
            end
            
          end
                  
        end

        ## now we have done all incrementes for all the transactions, we
        ## need to update the cached_status for for the transactor
        update_status_cache(applications,users)
        
        ## the time bucket has elapsed, trigger a cassandra job
        if @cass_enabled
          storage.zadd(changed_keys_key, @@current_bucket.to_i, @@current_bucket)
          if schedule_cassandra_job
            ## this will happend every X seconds, N times. Where N is the number of workers
            ## and X is a configuration parameter
            Resque.enqueue(StatsJob, @@current_bucket)
          end
        end
        
      end
  
      def get_value_of_set_if_exists(value_str) 
        return nil if value_str.nil? || value_str[0]!="#" 
        return value_str[1..value_str.size].to_i
      end
      
      def reset_current_bucket!
        @@current_bucket = nil
      end
      
      def current_bucket
        @@current_bucket 
      end
        
      private

      def aggregate(transaction)
        service_prefix     = service_key_prefix(transaction[:service_id])
        application_prefix = application_key_prefix(service_prefix, transaction[:application_id])
	
        # this one is for the limits of the users
        if transaction[:user_id].nil?
          user_prefix = nil
        else
          user_prefix = user_key_prefix(service_prefix,transaction[:user_id])
        end

        timestamp = transaction[:timestamp]
        
        ##FIXME, here we have to check that the timestamp is in the current given the time period we are in
        

        transaction[:usage].each do |metric_id, value|
          
          val = get_value_of_set_if_exists(value)
          if val.nil?
            type = :increment
          else
            type = :set
            value = val
          end
          
          value = value.to_i
          
          service_metric_prefix = metric_key_prefix(service_prefix, metric_id)

          ## QUESTION: why not increment by :year ?  
          increment_or_set(type, service_metric_prefix, :eternity,   nil,       value)
          increment_or_set(type, service_metric_prefix, :month,      timestamp, value)
          increment_or_set(type, service_metric_prefix, :week,       timestamp, value)
          increment_or_set(type, service_metric_prefix, :day,        timestamp, value)
          increment_or_set(type, service_metric_prefix, :hour,       timestamp, value)

          application_metric_prefix = metric_key_prefix(application_prefix, metric_id)

          increment_or_set(type, application_metric_prefix, :eternity,   nil,       value)
          increment_or_set(type, application_metric_prefix, :year,       timestamp, value)
          increment_or_set(type, application_metric_prefix, :month,      timestamp, value)
          increment_or_set(type, application_metric_prefix, :week,       timestamp, value)
          increment_or_set(type, application_metric_prefix, :day,        timestamp, value)
          increment_or_set(type, application_metric_prefix, :hour,       timestamp, value)
          increment_or_set(type, application_metric_prefix, :minute,     timestamp, value, :expires_in => 180)

          # increase the TTL from 1 to 3 minutes, only required for checking consistency between cassandra and
          # redis data. The overhead is not that big, will be at most few thousand extra keys.

          unless transaction[:user_id].nil? 
            user_metric_prefix = metric_key_prefix(user_prefix, metric_id)
            increment_or_set(type, user_metric_prefix, :eternity,   nil,       value)
            increment_or_set(type, user_metric_prefix, :year,       timestamp, value)
            increment_or_set(type, user_metric_prefix, :month,      timestamp, value)
            increment_or_set(type, user_metric_prefix, :week,       timestamp, value)
            increment_or_set(type, user_metric_prefix, :day,        timestamp, value)
            increment_or_set(type, user_metric_prefix, :hour,       timestamp, value)
            increment_or_set(type, user_metric_prefix, :minute,     timestamp, value, :expires_in => 180)
          end
        end

        update_application_set(service_prefix, transaction[:application_id])
        update_user_set(service_prefix, transaction[:user_id]) unless transaction[:user_id].nil?
      end		


      ## copied from transactor.rb
      def load_user_current_usage(user)
        pairs = user.usage_limits.map do |usage_limit|
          [usage_limit.metric_id, usage_limit.period]
        end
        if pairs.nil? or pairs.size==0 
          return {}
        end
        # preloading metric names
        user.metric_names = ThreeScale::Core::Metric.load_all_names(user.service_id, pairs.map{|e| e.first}.uniq)
        now = Time.now.getutc
        keys = pairs.map do |metric_id, period|
          user_usage_value_key(user, metric_id, period, now)
        end
        raw_values = storage.mget(*keys)
        values     = {}
        pairs.each_with_index do |(metric_id, period), index|
          values[period] ||= {}
          values[period][metric_id] = raw_values[index].to_i
        end
        values
      end

      ## copied from transactor.rb
      def load_current_usage(application)
        pairs = application.usage_limits.map do |usage_limit|
          [usage_limit.metric_id, usage_limit.period]
        end
        ## Warning this makes the test transactor_test.rb fail, weird because it didn't happen before
        if pairs.nil? or pairs.size==0 
          return {}
        end
        # preloading metric names
        application.metric_names = ThreeScale::Core::Metric.load_all_names(application.service_id, pairs.map{|e| e.first}.uniq)
        now = Time.now.getutc
        keys = pairs.map do |metric_id, period|
          usage_value_key(application, metric_id, period, now)
        end
        raw_values = storage.mget(*keys) 
        values     = {}
        pairs.each_with_index do |(metric_id, period), index|
          values[period] ||= {}
          values[period][metric_id] = raw_values[index].to_i
        end
        values
      end

      ## copied from transactor.rb
      def usage_value_key(application, metric_id, period, time)
        if period == :eternity
          encode_key("stats/{service:#{application.service_id}}/" +
                   "cinstance:#{application.id}/metric:#{metric_id}/" +
                   "#{period}")
        else
          encode_key("stats/{service:#{application.service_id}}/" +
                   "cinstance:#{application.id}/metric:#{metric_id}/" +
                   "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
        end

      end

      ## copied from transactor.rb
      def user_usage_value_key(user, metric_id, period, time)
        if period == :eternity
          encode_key("stats/{service:#{user.service_id}}/" +
                   "uinstance:#{user.username}/metric:#{metric_id}/" +
                   "#{period}")
        else
          encode_key("stats/{service:#{user.service_id}}/" +
                   "uinstance:#{user.username}/metric:#{metric_id}/" +
                   "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
        end
      end

      def update_status_cache(applications, users = {}) 

        current_timestamp = Time.now.getutc

        applications.each do |appid, values|

          application = Application.load(values[:service_id],values[:application_id])
          usage = load_current_usage(application)	
          status = ThreeScale::Backend::Transactor::Status.new(:application => application, :values => usage)					
          ThreeScale::Backend::Validators::Limits.apply(status,{})

          max_utilization, max_record = utilization(status)
          update_utilization(status,max_utilization, max_record,current_timestamp) if max_utilization>=0.0
          
          set_status_in_cache_application(values[:service_id],application,status,{:exclude_user => true})
        
        end

        users.each do |userid, values|

          service ||= Service.load_by_id(values[:service_id])
          raise ServiceLoadInconsistency.new(values[:service_id],service.id) if service.id != values[:service_id] 
          user = User.load_or_create!(service,values[:user_id])
          usage = load_user_current_usage(user)	
          status = ThreeScale::Backend::Transactor::Status.new(:user => user, :user_values => usage)					
          ThreeScale::Backend::Validators::Limits.apply(status,{})
         
          key = caching_key(service.id,:user,user.username)
          set_status_in_cache(key,status,{:exclude_application => true})

        end
      end

      def service_key_prefix(service_id)
        # The { ... } is the key tag. See redis docs for more info about key tags.
        "stats/{service:#{service_id}}"
      end

      def application_key_prefix(prefix, application_id)
        # XXX: For backwards compatibility, this is called cinstance. It will be eventually
        # renamed to application...
        "#{prefix}/cinstance:#{application_id}"
      end

      def user_key_prefix(prefix, user_id)
        # XXX: For backwards compatibility, this is called cinstance. It will be eventually
        # renamed to application...
        "#{prefix}/uinstance:#{user_id}"
      end	

      def metric_key_prefix(prefix, metric_id)
        "#{prefix}/metric:#{metric_id}"
      end
      
     
      def increment_or_set(type, prefix, granularity, timestamp, value, options = {})
        key = counter_key(prefix, granularity, timestamp)
      
        if (type==:set)
          if @cass_enabled
            ## will do later on, otherwise it overwrites the value
          else
            storage.set(key, value)
          end
          ## TODO: when on set, the stats to cassandra are not set
        else
          storage.incrby(key, value)
        end  
        
        storage.expire(key, options[:expires_in]) if options[:expires_in]
        
        if @cass_enabled
          storage.sadd(changed_keys_bucket_key(@@current_bucket),key)
          ## need to copy them besides marking, otherwise they could expire or get removed from redis
          ## with lost of data
          if type==:set
            @keys_doing_set_op << [key, value]
          else
            storage.incrby("#{@@current_bucket}:#{key}", value)
          end
        end
        
        
      end
      
      ## the common key for redis
      ## "stats/{service:123}/uinstance:user_id/metric:metric_id/month:20120401"
      ## is split into row and column key like this:
      ## "stats/{service:123}/uinstance:user_id/metric:metric_id/month:2012" , "20120401"
      ## 
      ## "stats/{service:123}/uinstance:user_id/metric:metric_id/eternity"
      ## "stats/{service:123}/uinstance:user_id/metric:metric_id/eternity", "eternity"
      ##
      ## we need to bucket per year since cassandra cannot have rows with zillions of columns, it's advised to keep it under 10MB
      ## if we store minutes per year 365 * 24 * 60 * 8 (assuming it's 8 bytes per counter) = 4.2MB so we are ok.
      ##
      def counter_key_cassandra(prefix, granularity, timestamp)
        if granularity == :eternity
          bucket, row_key = :eternity, :eternity
        else
          time = timestamp.beginning_of_cycle(granularity)
          row_key = time.to_compact_s
          bucket = "#{granularity}:#{row_key[0..3]}"
        end

        ["#{prefix}/#{bucket}".to_s, row_key.to_s]
      end
      
      def counter_key(prefix, granularity, timestamp)
        time_part = if granularity == :eternity
                      :eternity
                    else
                      time = timestamp.beginning_of_cycle(granularity)
                      "#{granularity}:#{time.to_compact_s}"
                    end

        "#{prefix}/#{time_part}"
      end

      def update_application_set(prefix, application_id)
        key = encode_key("#{prefix}/cinstances")
        storage.sadd(key, encode_key(application_id))
      end
      
      def update_user_set(prefix, user_id)
        key = encode_key("#{prefix}/uinstances")
        storage.sadd(key, encode_key(user_id))
      end

     
      def storage
        Storage.instance
      end
      
      def storage_cassandra
        StorageCassandra.instance
      end
      
    end
  end
end
