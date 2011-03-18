require 'json'
require 'ruby-debug'

module ThreeScale
  module Backend
    module Aggregator
	
      include Core::StorageKeyHelpers
			

      extend self
		
      def aggregate_all(transactions)
				applications = Hash.new
        transactions.each_slice(PIPELINED_SLICE_SIZE) do |slice|
          storage.pipelined do
            slice.each do |transaction|

							key = transaction[:application_id]
							key = transaction[:user_key] if key.nil?
						 	key = "#{key}##{transaction[:user_id]}" unless transaction[:user_id].nil? || transaction[:user_id].empty?

							## the key must be application+user if users exists since this is the lowest
							## granularity.
							## applications contains the list of application, or application+users that need to be limit checked
						
							applications[key] = {:application_id => transaction[:application_id], :user_key => transaction[:user_key], :service_id => transaction[:service_id], :user_id => transaction[:user_id], :no_body => transaction[:no_body]}

              aggregate(transaction)
            end
          end
        end

				## now we have done all incrementes for all the transactions, we
				## need to update the cached_status for for the transactor

				update_status_cache(applications)
				
      end

      private

			def aggregate(transaction)
        service_prefix     = service_key_prefix(transaction[:service_id])
        application_prefix = application_key_prefix(service_prefix, transaction[:application_id])
	
				# this one is for the limits of the users
				if transaction[:user_id].nil?
					user_application_prefix = nil
				else
					user_application_prefix = user_application_key_prefix(application_prefix,transaction[:user_id])
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

					if not user_application_prefix.nil?

						user_application_metric_prefix = metric_key_prefix(user_application_prefix, metric_id)
	
						increment(user_application_metric_prefix, :eternity,   nil,       value)
          	increment(user_application_metric_prefix, :year,       timestamp, value)
          	increment(user_application_metric_prefix, :month,      timestamp, value)
          	increment(user_application_metric_prefix, :week,       timestamp, value)
          	increment(user_application_metric_prefix, :day,        timestamp, value)
          	increment(user_application_metric_prefix, :hour,       timestamp, value)
          	increment(user_application_metric_prefix, :minute,     timestamp, value, :expires_in => 60)

					end
					

        end

        update_application_set(service_prefix, transaction[:application_id])
      end		

			## copied from transactor.rb
			def usage_value_key(application, user_id, metric_id, period, time)
        encode_key("stats/{service:#{application.service_id}}/" +
                   "cinstance:#{application_and_user_key(application,user_id)}/metric:#{metric_id}/" +
                   "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
      end

			## copied from transactor.rb
			def load_current_usage(application, user_id)
        pairs = application.usage_limits.map do |usage_limit|
          [usage_limit.metric_id, usage_limit.period]
        end

        return {} if pairs.empty?

        # preloading metric names
        application.metric_names = ThreeScale::Core::Metric.load_all_names(application.service_id, pairs.map{|e| e.first}.uniq)


        now = Time.now.getutc

        keys = pairs.map do |metric_id, period|
          usage_value_key(application, user_id, metric_id, period, now)
        end

        raw_values = storage.mget(*keys)
        values     = {}

        pairs.each_with_index do |(metric_id, period), index|
          values[period] ||= {}
          values[period][metric_id] = raw_values[index].to_i
        end

        values
      end


	
			def update_status_cache(applications) 

				applications.each do |appid, values|
	
					application = Application.load_by_id_or_user_key!(values[:service_id],values[:application_id],values[:user_key])

					user_id = values[:user_id]

					## should we raise this UserNotDefined error here? This error might be 
					## relevant for the requester only. Also, this should never happens unless
					## the application.plan_type is forcefully changed. The user_id should be defined
					## here unless we forgot to add it to resque :-) probably our fault
					raise UserNotDefined, application.id if application.user_required? && (user_id.nil? || user_id.empty?)
					
					usage = load_current_usage(application,user_id)	
				
					status = ThreeScale::Backend::Transactor::Status.new(:application => application, :values => usage)					
					ThreeScale::Backend::Validators::Limits.apply(status,{})

					app_user_key = application_and_user_key(application,user_id)

					
					if status.authorized?
						storage.pipelined do 
							key = "cached_status/#{app_user_key}"
							storage.set(key,status.to_xml(:anchors_for_caching => true))
							storage.expire(key,60-Time.now.sec)
							storage.srem("limit_violations_set",app_user_key)
						end
					else
						## it just violated the Limits, add to the violation set
						storage.pipelined do 
							key = "cached_status/#{app_user_key}"
							storage.set(key,status.to_xml(:anchors_for_caching => true))
							storage.expire(key,60-Time.now.sec)
							storage.sadd("limit_violations_set",app_user_key)
						end 
					end

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

			def user_application_key_prefix(prefix, user_id)
        # XXX: For backwards compatibility, this is called cinstance. It will be eventually
        # renamed to application...
        "#{prefix}##{user_id}"
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

			# copied from transactor.rb
			def application_and_user_key(application, user_id)
				key = "#{application.id}"
				key
			end

      def storage
        Storage.instance
      end
    end
  end
end
