require 'json'

require '3scale/backend/cache'
require '3scale/backend/alerts'
require '3scale/backend/errors'

module ThreeScale
  module Backend
    module Aggregator
      include Core::StorageKeyHelpers
      include Backend::Cache
      include Backend::Alerts
      extend self

      def aggregate_all(transactions)
        applications = Hash.new
        users = Hash.new

        transactions.each_slice(PIPELINED_SLICE_SIZE) do |slice|
          storage.pipelined do
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
        end

        ## now we have done all incrementes for all the transactions, we
        ## need to update the cached_status for for the transactor
        update_status_cache(applications,users)
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

        transaction[:usage].each do |metric_id, value|
          service_metric_prefix = metric_key_prefix(service_prefix, metric_id)

          increment(service_metric_prefix, :eternity,   nil,       value)
          increment(service_metric_prefix, :month,      timestamp, value)
          increment(service_metric_prefix, :week,       timestamp, value)
          increment(service_metric_prefix, :day,        timestamp, value)
          increment(service_metric_prefix, :hour,       timestamp, value)

          application_metric_prefix = metric_key_prefix(application_prefix, metric_id)

          increment(application_metric_prefix, :eternity,   nil,       value)
          increment(application_metric_prefix, :year,       timestamp, value)
          increment(application_metric_prefix, :month,      timestamp, value)
          increment(application_metric_prefix, :week,       timestamp, value)
          increment(application_metric_prefix, :day,        timestamp, value)
          increment(application_metric_prefix, :hour,       timestamp, value)
          increment(application_metric_prefix, :minute,     timestamp, value, :expires_in => 60)

          unless transaction[:user_id].nil? 
            user_metric_prefix = metric_key_prefix(user_prefix, metric_id)
            increment(user_metric_prefix, :eternity,   nil,       value)
            increment(user_metric_prefix, :year,       timestamp, value)
            increment(user_metric_prefix, :month,      timestamp, value)
            increment(user_metric_prefix, :week,       timestamp, value)
            increment(user_metric_prefix, :day,        timestamp, value)
            increment(user_metric_prefix, :hour,       timestamp, value)
            increment(user_metric_prefix, :minute,     timestamp, value, :expires_in => 60)
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
        encode_key("stats/{service:#{application.service_id}}/" +
                   "cinstance:#{application.id}/metric:#{metric_id}/" +
                   "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
      end

      ## copied from transactor.rb
      def user_usage_value_key(user, metric_id, period, time)
        encode_key("stats/{service:#{user.service_id}}/" +
                   "uinstance:#{user.username}/metric:#{metric_id}/" +
                   "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
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
          user = User.load!(service,values[:user_id])
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

      def increment(prefix, granularity, timestamp, value, options = {})
        key = counter_key(prefix, granularity, timestamp)
        updated_value = storage.incrby(key, value)
        storage.expire(key, options[:expires_in]) if options[:expires_in]
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
    end
  end
end
