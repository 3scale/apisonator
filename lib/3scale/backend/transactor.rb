require 'json'
require 'ruby-debug'

require '3scale/backend/transactor/notify_job'
require '3scale/backend/transactor/process_job'
require '3scale/backend/transactor/report_job'
require '3scale/backend/transactor/status'
require '3scale/backend/cache'
require '3scale/backend/errors'

module ThreeScale
  module Backend
    # Methods for reporting and authorizing transactions.
    module Transactor
      include Core::StorageKeyHelpers
      include Backend::Cache
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

    
      OAUTH_VALIDATORS = [Validators::OauthSetting,
                          Validators::OauthKey,
                          Validators::RedirectUrl,
                          Validators::Referrer,
                          Validators::ReferrerFilters,
                          Validators::State,
                          Validators::Limits]

    
      def authorize(provider_key, params, options = {})
        notify(provider_key, 'transactions/authorize' => 1)

        status = nil
        status_xml = nil
        status_result = nil   
        need_nocache = true

        if params[:no_caching].nil?

          ## check is the keys/id combination from params has been seen
          ## before
          isknown, service_id, data_combination, dirty_app_xml, dirty_user_xml = combination_seen(provider_key,params)
          ## warning, this way of building application_id might be problematic.   
          application_id = params[:app_id] 
          application_id = params[:user_key] if application_id.nil?
          username = params[:user_id]

          options[:dirty_app_xml] = dirty_app_xml
          options[:dirty_user_xml] = dirty_user_xml

          options[:usage] = params[:usage] unless params[:usage].nil?
          options[:add_usage_on_report] = true unless params[:usage].nil?

          if isknown && !service_id.nil?

            status_xml, status_result = get_status_in_cache(service_id, application_id, username, params[:usage], options)
            if status_xml.nil? || status_result.nil? 
              need_nocache = true
            else
              ## that's the nice case, everything was cached
              need_nocache = false
            end
          else
            need_nocache = true
          end
        end

        if need_nocache         
          ## this are the classic calls to the methods, but they need to return 
          ## additional objects

          status, service, application, user = authorize_nocache(provider_key,params,options)

          service_id = service.id
          application_id = application.id
          username = nil
          username = user.username unless user.nil?

          if params[:no_caching].nil?
            combination_save(data_combination) unless data_combination.nil?

            

            if (user.nil?)
              key = caching_key(service.id,:application,application.id)
              set_status_in_cache(key,status)
            else
              key = caching_key(service.id,:application,application.id)
              set_status_in_cache(key,status,{:exclude_user => true})
              key = caching_key(service.id,:user,user.username)
              set_status_in_cache(key,status,{:exclude_application => true})
            end
          end
        end

       

        [status, status_xml, status_result]

      end

      def authorize_nocache(provider_key, params, options = {})
        

        service     = Service.load!(provider_key)
        application = Application.load_by_id_or_user_key!(service.id,
                                                          params[:app_id],
                                                          params[:user_key])

        if not (params[:user_id].nil? || params[:user_id].empty?)
          ## user_id on the paramters
          if application.user_required? 
            user = User.load!(service,params[:user_id])
            raise UserRequiresRegistration, service.id, params[:user_id] if user.nil?     
          else
            user = nil
            params[:user_id] = nil
          end
        else
          raise UserNotDefined, application.id if application.user_required?
          params[:user_id]=nil
        end
        
        usage = load_current_usage(application)
        user_usage = load_user_current_usage(user) unless user.nil?

        usage  = load_current_usage(application)
        status = Status.new(:service     => service, :application => application, :values => usage, :user => user, :user_values => user_usage).tap do |st|
          VALIDATORS.all? do |validator|
            if validator == Validators::Referrer && !st.service.referrer_filters_required?
              true
            else
              validator.apply(st, params)
            end
          end
        end 

        return [status, service, application, user]

      end

      def oauth_authorize(provider_key, params, options = {})
        notify(provider_key, 'transactions/authorize' => 1)

        status = nil
        status_xml = nil
        status_result = nil   
        need_nocache = true

        if params[:no_caching].nil?
          ## check is the keys/id combination from params has been seen
          ## before
          isknown, service_id, data_combination, dirty_app_xml, dirty_user_xml = combination_seen(provider_key,params)
          ## warning, this way of building application_id might be problematic.   
          application_id = params[:app_id] 
          application_id = params[:user_key] if application_id.nil?
          username = params[:user_id]

          options[:dirty_app_xml] = dirty_app_xml
          options[:dirty_user_xml] = dirty_user_xml

          options[:usage] = params[:usage] unless params[:usage].nil?
          options[:add_usage_on_report] = true unless params[:usage].nil?

          if isknown && !service_id.nil?
            status_xml, status_result = get_status_in_cache(service_id, application_id, username, params[:usage], options)
            if status_xml.nil? || status_result.nil? 
              need_nocache = true
            else
              ## that's the nice case, everything was cached
              need_nocache = false
            end
          else
            need_nocache = true
          end
        end

        if need_nocache         
          ## this are the classic calls to the methods, but they need to return 
          ## additional objects
          status, service, application, user = oauth_authorize_nocache(provider_key,params,options)

          service_id = service.id
          application_id = application.id
          username = nil
          username = user.username unless user.nil?

          if params[:no_caching].nil?
            combination_save(data_combination) unless data_combination.nil?

            if (user.nil?)
              key = caching_key(service.id,:application,application.id)
              set_status_in_cache(key,status)
            else
              key = caching_key(service.id,:application,application.id)
              set_status_in_cache(key,status,{:exclude_user => true})
              key = caching_key(service.id,:user,user.username)
              set_status_in_cache(key,status,{:exclude_application => true})
            end
          end
        end

        [status, status_xml, status_result]

      end

      def oauth_authorize_nocache(provider_key, params, options = {})
    
        service = Service.load!(provider_key)
        application =  Application.load_by_id_or_user_key!(service.id,
                                                          params[:app_id],
                                                          params[:user_key])

        if not (params[:user_id].nil? || params[:user_id].empty?)
          ## user_id on the paramters
          if application.user_required? 
            user = User.load!(service,params[:user_id])
            raise UserRequiresRegistration, service.id, params[:user_id] if user.nil?     
          else
            user = nil
            params[:user_id] = nil
          end
        else
          raise UserNotDefined, application.id if application.user_required?
          params[:user_id]=nil
        end
        
        usage = load_current_usage(application)
        user_usage = load_user_current_usage(user) unless user.nil?

        status = Status.new(:service     => service, :application => application, :values => usage, :user => user, :user_values => user_usage).tap do |status|
          OAUTH_VALIDATORS.all? do |validator|
            if validator == Validators::Referrer && !status.service.referrer_filters_required?
              true
            else
              validator.apply(status, params)
            end
          end
        end
    
        return [status, service, application, user]       

      end

    

      def authrep(provider_key, params, options ={})

        status = nil
        status_xml = nil
        status_result = nil   
        need_nocache = true

        if params[:no_caching].nil?
          ## check is the keys/id combination from params has been seen
          ## before
          isknown, service_id, data_combination, dirty_app_xml, dirty_user_xml = combination_seen(provider_key,params)
          ## warning, this way of building application_id might be problematic.   
          application_id = params[:app_id] 
          application_id = params[:user_key] if application_id.nil?
          username = params[:user_id]

          options[:dirty_app_xml] = dirty_app_xml
          options[:dirty_user_xml] = dirty_user_xml

          options[:usage] = params[:usage] unless params[:usage].nil?
          options[:add_usage_on_report] = true unless params[:usage].nil?

          if isknown && !service_id.nil?
            status_xml, status_result = get_status_in_cache(service_id, application_id, username, options)
            if status_xml.nil? || status_result.nil? 
              need_nocache = true
            else
              ## that's the nice case, everything was cached
              need_nocache = false
            end
          else
            need_nocache = true
          end
        end

        if need_nocache         
          ## this are the classic calls to the methods, but they need to return 
          ## additional objects
          status, service, application, user = authrep_nocache(provider_key,params,options)

          service_id = service.id
          application_id = application.id
          username = nil
          username = user.username unless user.nil?

          if params[:no_caching].nil?
            combination_save(data_combination) unless data_combination.nil?

            if (user.nil?)
              key = caching_key(service.id,:application,application.id)
              set_status_in_cache(key,status)
            else
              key = caching_key(service.id,:application,application.id)
              set_status_in_cache(key,status,{:exclude_user => true})
              key = caching_key(service.id,:user,user.username)
              set_status_in_cache(key,status,{:exclude_application => true})
            end
          end
        end

        if !params[:usage].nil? && ((!status.nil? && status.authorized?) || (status.nil? && status_result)) 
          storage.pipelined do
            report_enqueue(service_id, ({ 0 => {"app_id" => application_id, "usage" => params[:usage], "user_id" => username}}))
            notify(provider_key, 'transactions/authorize' => 1, 'transactions/create_multiple' => 1, 'transactions' => params[:usage].size)
          end
        else
          notify(provider_key, 'transactions/authorize' => 1)
        end

        [status, status_xml, status_result]       

      end
 
      ## this is the classic way to do an authrep in case the cache fails, there has been changes
      ## on the underlying data or the time to life has elapsed
      def authrep_nocache(provider_key, params, options ={})
        status = nil
        user = nil
        user_usage = nil

        service = Service.load!(provider_key)
        application =  Application.load_by_id_or_user_key!(service.id,
                                                          params[:app_id],
                                                          params[:user_key])

        if not (params[:user_id].nil? || params[:user_id].empty?)
          ## user_id on the paramters
          if application.user_required? 
            user = User.load!(service,params[:user_id])
            raise UserRequiresRegistration, service.id, params[:user_id] if user.nil?     
          else
            user = nil
            params[:user_id] = nil
          end
        else
          raise UserNotDefined, application.id if application.user_required?
          params[:user_id]=nil
        end
        
        usage = load_current_usage(application)
        user_usage = load_user_current_usage(user) unless user.nil?

        status = Status.new(:service => service, :application => application, :values => usage, :user => user, :user_values => user_usage).tap do |st|
          VALIDATORS.all? do |validator|
            if validator == Validators::Referrer && !st.service.referrer_filters_required?
              true
            else
              validator.apply(st, params)
            end
          end
        end

        return [status, service, application, user]        

      rescue ThreeScale::Backend::ApplicationNotFound, ThreeScale::Backend::UserNotDefined => e 
        # we still want to track these
        notify(provider_key, 'transactions/authorize' => 1)
        raise e
      end

      ## -------------------
      
      private


      def run_validators(validators_set, service, application, user, params)
        status = Status.new(:service => service, :application => application).tap do |st|
          validators_set.all? do |validator|
            if validator == Validators::Referrer && !st.service.referrer_filters_required?
              true
            else
              validator.apply(st, params)
            end
          end
        end
        return status
      end

      def check_for_users(service, application, params)
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
        return params
      end

      def report_enqueue(service_id, data)
        Resque.enqueue(ReportJob, service_id, data)
      end

      def notify(provider_key, usage)
        Resque.enqueue(NotifyJob, provider_key, usage, encode_time(Time.now.getutc))
      end

      def encode_time(time)
        time.to_s
      end

      def parse_predicted_usage(service, usage)
        ## warning, empty method? :-)
      end

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

      def usage_value_key(application, metric_id, period, time)
        encode_key("stats/{service:#{application.service_id}}/" +
                   "cinstance:#{application.id}/metric:#{metric_id}/" +
                   "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
      end

      def user_usage_value_key(user, metric_id, period, time)
        encode_key("stats/{service:#{user.service_id}}/" +
                   "uinstance:#{user.username}/metric:#{metric_id}/" +
                   "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
      end



      def storage
        Storage.instance
      end
    end
  end
end
