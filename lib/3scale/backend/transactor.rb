require 'json'
require 'ruby-debug'

require '3scale/backend/transactor/notify_job'
require '3scale/backend/transactor/process_job'
require '3scale/backend/transactor/report_job'
require '3scale/backend/transactor/status'

module ThreeScale
  module Backend
    # Methods for reporting and authorizing transactions.
    module Transactor
      include Core::StorageKeyHelpers

      extend self

      def report(provider_key, transactions)
        service_id = Service.load_id!(provider_key)

				report_enqueue(service_id, transactions)
        #Resque.enqueue(ReportJob, service_id, transactions)

        notify(provider_key, 'transactions/create_multiple' => 1,
                             'transactions' => transactions.size)
      end

      VALIDATORS = [Validators::Key,
                    Validators::Referrer,
                    Validators::ReferrerFilters,
                    Validators::State,
                    Validators::Limits]

			VALIDATORS_WITHOUT_LIMITS = [Validators::Key,
                    Validators::Referrer,
                    Validators::ReferrerFilters,
                    Validators::State]

      OAUTH_VALIDATORS = [Validators::OauthSetting,
                          Validators::OauthKey,
                          Validators::RedirectUrl,
                          Validators::Referrer,
                          Validators::ReferrerFilters,
                          Validators::State,
                          Validators::Limits]

      def authorize(provider_key, params)
        notify(provider_key, 'transactions/authorize' => 1)

        service     = Service.load!(provider_key)
        application = Application.load_by_id_or_user_key!(service.id,
                                                          params[:app_id],
                                                          params[:user_key])

				## check that the user_id is defined if the application has limits on the user
				## problem firing the exception, warning, check it later with someone
				if application.user_required? 
					raise UserNotDefined, application.id if params[:user_id].nil? || params[:user_id].empty?

					if service.user_registration_required?
						raise UserRequiresRegistration, service.id, params[:user_id] unless service.user_exists?(params[:user_id])
					end

				else
					## for sanity, it's important to get rid of the request parameter :user_id if the 
					## plan is default. :user_id is passed all the way up and sometimes its existance
					## is the only way to know which application plan we are in (:default or :user) 
					params[:user_id] = nil
				end


status = Status.new(:service     => service,
                   :application => application).tap do |st|
        	VALIDATORS_WITHOUT_LIMITS.all? do |validator|
          	  if validator == Validators::Referrer && !st.service.referrer_filters_required?
          	    true
          	  else
          	    validator.apply(st, params)
          	  end
          	end
        end
				
				## now we have checked for all possible factors

				cached_status_text = nil
				cached_status_result = nil

				## app_user_key is the application.id if the plan is :default and application.id#user_id if the plan is :user
				app_user_key = application_and_user_key(application,params[:user_id])

				if status.authorized?

					ismember, cached_status_text = storage.pipelined do 
						storage.sismember("limit_violations_set",app_user_key)
						cached_status_text = storage.get("cached_status/#{app_user_key}")
					end
					
					cached_status_result = true if (ismember==0 or ismember==false) 

					if cached_status_text.nil?
						## could not get the cached value or the violation just ellapsed
						cached_status_result = nil					

						usage = load_current_usage(application, params[:user_id])

						## rebuild status to add the usage, @values in Status is readonly?
						status = Status.new(:service     => service,
                   :application => application,
                   :values      => usage)
						## don't do Validators::Limits.apply(status,params) to avoid preemptive checking
						## of the usage
						Validators::Limits.apply(status,{})
			
						
						if status.authorized?
							## it just violated the Limits, add to the violation set
							storage.pipelined do 
								key = "cached_status/#{app_user_key}"
								storage.set(key,status.to_xml({:anchors_for_caching => true}))
								storage.expire(key,60-Time.now.sec)
								storage.srem("limit_violations_set",app_user_key)
							end
						else
							## it just violated the Limits, add to the violation set
							storage.pipelined do 
								key = "cached_status/#{app_user_key}"
								storage.set(key,status.to_xml({:anchors_for_caching => true}))
								storage.expire(key,60-Time.now.sec)
								storage.sadd("limit_violations_set",app_user_key)
							end 
						end
					
					end

				
					storage.pipelined do
							if (cached_status_result.nil? || cached_status_result) && status.authorized? && !params[:usage].nil? && !params[:usage].empty?

								## don't forget to add the user_id

								report_enqueue(service.id, ({ 0 => {"app_id" => application.id, "usage" => params[:usage], "user_id" => params[:user_id], "no_body" => params[:no_body]}}))

	          		#Resque.enqueue(ReportJob, service.id, ({ 0 => {"app_id" => application.id, "usage" => params[:usage], "no_body" => params[:no_body]}}))

	     	     		notify(provider_key, 'transactions/authorize' => 1, 'transactions/create_multiple' => 1, 'transactions' => params[:usage].size)
	     	   		else
	     	     		notify(provider_key, 'transactions/authorize' => 1)
	     	   		end
					end

					return [status, cached_status_text, cached_status_result]

				else
					## because the validator (other that limits failed) we return a new
					## object				
					return [status, nil, nil]
				end
      rescue ThreeScale::Backend::ApplicationNotFound, ThreeScale::Backend::UserNotDefined => e 
				# we still want to track these
        notify(provider_key, 'transactions/authorize' => 1)
        raise e
      end

      def oauth_authorize(provider_key, params)
        notify(provider_key, 'transactions/authorize' => 1)

        service     = Service.load!(provider_key)
        application = Application.load_by_id_or_user_key!(service.id,
                                                          params[:app_id],
                                                          params[:user_key])
        usage       = load_current_usage(application)

        Status.new(:service     => service,
                   :application => application,
                   :values      => usage).tap do |status|
          OAUTH_VALIDATORS.all? do |validator|
            if validator == Validators::Referrer && !status.service.referrer_filters_required?
              true
            else
              validator.apply(status, params)
            end
          end
        end
      end

      def authrep(provider_key, params)

				status = nil
			  service = Service.load!(provider_key)

				
        application =  Application.load_by_id_or_user_key!(service.id,
                                                          params[:app_id],
                                                          params[:user_key])
				
				

				## check that the user_id is defined if the application has limits on the user
				## problem firing the exception, warning, check it later with someone
				if application.user_required? 
					raise UserNotDefined, application.id if params[:user_id].nil? || params[:user_id].empty?

					if service.user_registration_required?
						raise UserRequiresRegistration, service.id, params[:user_id] unless service.user_exists?(params[:user_id])
					end

				else
					## for sanity, it's important to get rid of the request parameter :user_id if the 
					## plan is default. :user_id is passed all the way up and sometimes its existance
					## is the only way to know which application plan we are in (:default or :user) 
					params[:user_id] = nil
				end

			
				
				

				status = Status.new(:service     => service,
                   :application => application).tap do |st|
        	VALIDATORS_WITHOUT_LIMITS.all? do |validator|
          	  if validator == Validators::Referrer && !st.service.referrer_filters_required?
          	    true
          	  else
          	    validator.apply(st, params)
          	  end
          	end
        end
				
				## now we have checked for all possible factors

				cached_status_text = nil
				cached_status_result = nil

				## app_user_key is the application.id if the plan is :default and application.id#user_id if the plan is :user
				app_user_key = application_and_user_key(application,params[:user_id])

				if status.authorized?

					ismember, cached_status_text = storage.pipelined do 
						storage.sismember("limit_violations_set",app_user_key)
						cached_status_text = storage.get("cached_status/#{app_user_key}")
					end
					
					cached_status_result = true if (ismember==0 or ismember==false) 

					if cached_status_text.nil?
						## could not get the cached value or the violation just ellapsed
						cached_status_result = nil					

						usage = load_current_usage(application, params[:user_id])

						## rebuild status to add the usage, @values in Status is readonly?
						status = Status.new(:service     => service,
                   :application => application,
                   :values      => usage)
						## don't do Validators::Limits.apply(status,params) to avoid preemptive checking
						## of the usage
						Validators::Limits.apply(status,{})
			
						
						if status.authorized?
							## it just violated the Limits, add to the violation set
							storage.pipelined do 
								key = "cached_status/#{app_user_key}"
								storage.set(key,status.to_xml({:anchors_for_caching => true}))
								storage.expire(key,60-Time.now.sec)
								storage.srem("limit_violations_set",app_user_key)
							end
						else
							## it just violated the Limits, add to the violation set
							storage.pipelined do 
								key = "cached_status/#{app_user_key}"
								storage.set(key,status.to_xml({:anchors_for_caching => true}))
								storage.expire(key,60-Time.now.sec)
								storage.sadd("limit_violations_set",app_user_key)
							end 
						end
					
					end

				
					storage.pipelined do
							if (cached_status_result.nil? || cached_status_result) && status.authorized? && !params[:usage].nil? && !params[:usage].empty?

								## don't forget to add the user_id

								report_enqueue(service.id, ({ 0 => {"app_id" => application.id, "usage" => params[:usage], "user_id" => params[:user_id], "no_body" => params[:no_body]}}))

	          		#Resque.enqueue(ReportJob, service.id, ({ 0 => {"app_id" => application.id, "usage" => params[:usage], "no_body" => params[:no_body]}}))

	     	     		notify(provider_key, 'transactions/authorize' => 1, 'transactions/create_multiple' => 1, 'transactions' => params[:usage].size)
	     	   		else
	     	     		notify(provider_key, 'transactions/authorize' => 1)
	     	   		end
					end


					

					return [status, cached_status_text, cached_status_result]

				else
					## because the validator (other that limits failed) we return a new
					## object

				
					return [status, nil, nil]
				end
      rescue ThreeScale::Backend::ApplicationNotFound, ThreeScale::Backend::UserNotDefined => e 
				# we still want to track these
        notify(provider_key, 'transactions/authorize' => 1)
        raise e
      end


			def self.put_limit_violation(application_id, expires_in)
				key = "limit_violations/#{application_id}"
				storage.pipelined do 
					storage.set(key,1) 
					storage.expire(key,expires_in) 
					storage.sadd("limit_violations_set",application_id)
				end
			end

			## this one is hacky, handle with care. This updates the cached xml so that we can increment 
			## the current_usage. TODO: we can do limit checking here, however, the non-cached authrep does not	
			## cover this corner case either, e.g. it could be that the output is <current_value>101</current_value>
			## and <max_value>100</max_value> and still be authorized, the next authrep with fail be limits though.
			## This would have been much more elegant if we were caching serialized objects, but binary marshalling
			## is extremely slow, divide performance by 2, and marshalling is faster than json, yaml, byml, et
			## (benchmarked)

			def self.clean_cached_xml(xmlstr, options = {})

				v = xmlstr.split("|.|")
				newxmlstr = ""
				i=0

				v.each do |str|
					if (i%2==1)
						metric, curr_value, max_value = str.split(",")

						if (options[:usage].nil?) 
							str = curr_value
						else
					
							inc = options[:usage][metric].to_i	
							str = (curr_value.to_i + inc).to_s

						end
								
					end

					newxmlstr << str

					i=i+1
				end
				
				newxmlstr				
			end



      private

			def report_enqueue(service_id, data)
				## warning,
				## Resque.enqueue is extremely inefficient for an unknown reason. Converting to JSON and doing the
				## call directely to the redis queue is twice as fast, this can give an xtra 50-100 req/s, TODO someday
				Resque.enqueue(ReportJob, service_id, data)
			end


      def notify(provider_key, usage)
				## warning,
				## Resque.enqueue is extremely inefficient for an unknown reason. Converting to JSON and doing the
				## call directely to the redis queue is twice as fast, this can give an xtra 50-100 req/s, TODO someday
        Resque.enqueue(NotifyJob, provider_key, usage, encode_time(Time.now.getutc))
      end

      def encode_time(time)
        time.to_s
      end

      def parse_predicted_usage(service, usage)
				## warning, empty method? :-)
      end

      def load_current_usage(application, user_id)
        pairs = application.usage_limits.map do |usage_limit|
          [usage_limit.metric_id, usage_limit.period]
        end

        return {} if pairs.empty?

        # preloading metric names

				debugger
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

			def usage_value_key(application, metric_id, period, time)
        encode_key("stats/{service:#{application.service_id}}/" +
                   "cinstance:#{application.id}/metric:#{metric_id}/" +
                   "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
      end

			#def usage_value_key(application, user_id, metric_id, period, time)
      #  encode_key("stats/{service:#{application.service_id}}/" +
      #             "cinstance:#{application_and_user_key(application,user_id)}/metric:#{metric_id}/" +
      #             "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
      #end

			## this merges the application_id and the user_id to
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
