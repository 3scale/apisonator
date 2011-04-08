require 'json'

module ThreeScale
  module Backend
    # Methods for reporting and authorizing transactions.
    module Transactor
      autoload :NotifyJob,  '3scale/backend/transactor/notify_job'
      autoload :ProcessJob, '3scale/backend/transactor/process_job'
      autoload :ReportJob,  '3scale/backend/transactor/report_job'
      autoload :Status,     '3scale/backend/transactor/status'

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

      def authorize(provider_key, params)
        notify(provider_key, 'transactions/authorize' => 1)

        service     = Service.load!(provider_key)
        application = Application.load_by_id_or_user_key!(service.id,
                                                          params[:app_id],
                                                          params[:user_key])

				## check that the user_id is defined if the application has limits on the user
				## problem firing the exception, warning, check it later with someone
				raise UserNotDefined, application.id if (application.plan_type==:user && (params[:user_id].nil? || params[:user_id].empty?))

        usage       = load_current_usage(application, params[:user_id])

        Status.new(:service     => service,
                   :application => application,
                   :values      => usage).tap do |status|
          VALIDATORS.all? do |validator|
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
				raise UserNotDefined, application.id if (application.plan_type==:user && (params[:user_id].nil? || params[:user_id].empty?))

				## for sanity, it's important to get rid of the request parameter :user_id if the 
				## plan is default. :user_id is passed all the way up and sometimes its existance
				## is the only way to know which application plan we are in (:default or :user) 
				params[:user_id] = nil if application.plan_type==:default


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

				cached_status = nil

				## app_user_key is the application.id if the plan is :default and application.id#user_id if the plan is :user
				app_user_key = application_and_user_key(application,params[:user_id])

				if status.authorized?

					status = nil

					ismember, marshalled_cached_status = storage.pipelined do 
						storage.sismember("limit_violations_set",app_user_key)
						storage.get("cached_status/#{app_user_key}")
					end
					
					#cached_status_result = true if (ismember==0 or ismember==false) 

					begin
						status = Marshal::load(marshalled_cached_status) unless marshalled_cached_status.nil?		
					rescue Exception
						status = nil
					end
					
					if status.nil?
						## could not get the cached value or the violation just ellapsed
			
						usage = load_current_usage(application, params[:user_id])

						## rebuild status to add the usage, @values in Status is readonly?
						status = Status.new(:service     => service,
                   :application => application,
                   :values      => usage)
						## don't do Validators::Limits.apply(status,params) to avoid preemptive checking
						## of the usage
						Validators::Limits.apply(status,{})
			
			
						key = "cached_status/#{app_user_key}"
						if status.authorized?
							## it just violated the Limits, add to the violation set
							storage.pipelined do 
								storage.set(key,Marshal::dump(status))
								storage.expire(key,60-Time.now.sec)
								storage.srem("limit_violations_set",app_user_key)
							end
						else
							## it just violated the Limits, add to the violation set
							storage.pipelined do 
								storage.set(key,Marshal::dump(status))
								storage.expire(key,60-Time.now.sec)
								storage.sadd("limit_violations_set",app_user_key)
							end 
						end
					
					end

				
					storage.pipelined do
							if status.authorized? && !params[:usage].nil? && !params[:usage].empty?

								## don't forget to add the user_id
								report_enqueue(service.id, ({ 0 => {"app_id" => application.id, "usage" => params[:usage], "user_id" => params[:user_id], "no_body" => params[:no_body]}}))

	          		#Resque.enqueue(ReportJob, service.id, ({ 0 => {"app_id" => application.id, "usage" => params[:usage], "no_body" => params[:no_body]}}))

	     	     		notify(provider_key, 'transactions/authorize' => 1, 'transactions/create_multiple' => 1, 'transactions' => params[:usage].size)
	     	   		else
	     	     		notify(provider_key, 'transactions/authorize' => 1)
	     	   		end
					end

					 

				else
					## because the validator (other that limits failed) we return a new
					## object
					
				end

				status
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

			## warning, this method should be deprecated once the user limiting works, no-one should use it
      #def usage_value_key(application, metric_id, period, time)
      #  encode_key("stats/{service:#{application.service_id}}/" +
      #             "cinstance:#{application.id}/metric:#{metric_id}/" +
      #             "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
      #end

			def usage_value_key(application, user_id, metric_id, period, time)
        encode_key("stats/{service:#{application.service_id}}/" +
                   "cinstance:#{application_and_user_key(application,user_id)}/metric:#{metric_id}/" +
                   "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
      end

			## this merges the application_id and the user_id to
			def application_and_user_key(application, user_id)
				if application.plan_type==:default 
					key = "#{application.id}"
				else
					key = "#{application.id}##{user_id}"
				end			
				key
			end

      def storage
        Storage.instance
      end
    end
  end
end
