
require '3scale/backend/errors'

module ThreeScale
  module Backend
    # Methods for caching
    module Cache
      include Core::StorageKeyHelpers
      extend self

      VALID_PARAMS_FOR_CACHE = [:provider_key, 
                                :app_id, 
                                :app_key, 
                                :user_key, 
                                :user_id, 
                                :referrer,  
                                :redirect_url]

      COMBINATION_TTL       = 3600 # 1 hour
      STATUS_TTL            = 60   # 1 minute, this is too short but we need minute information on the output :-( 
      SERVICE_ID_CACHE_TTL  = 300  # 5 minutes
     
      ## this is a little bit dangerous, but we can live with it
      def get_service_id(provider_key)
        current_time = Time.now
        @@provider_key_2_service_id ||= Hash.new
        sid, time = @@provider_key_2_service_id[provider_key]
        if sid.nil? || (current_time-time > SERVICE_ID_CACHE_TTL)  
          sid = storage.get("service/provider_key:#{provider_key}/id")
          @@provider_key_2_service_id[provider_key] = [sid, current_time] unless sid.nil?
        end
        sid
      end

      def combination_seen(provider_key, params)  

        key_version = nil
        service_id = get_service_id(provider_key)      
       
        if !service_id.nil?
  
          key_version = "cache_combination/"
          VALID_PARAMS_FOR_CACHE.each do |label|
             key_version << "#{label}:#{params[label]}/"
          end 

          application_id = params[:app_id] 
          application_id = params[:user_key] if application_id.nil?
          username = params[:user_id]

          if username.nil?
            
            cached_app_key = caching_key(service_id,:application,application_id)

            version, ver_service, ver_application, dirty_app_xml = storage.mget(key_version,Service.storage_key(service_id, :version),Application.storage_key(service_id,application_id,:version),cached_app_key)
            
            current_version = "s:#{ver_service}/a:#{ver_application}"

          else

            cached_app_key = caching_key(service_id,:application,application_id)
            cached_user_key = caching_key(service_id,:user,username)
            
            version, ver_service, ver_application, ver_user, dirty_app_xml, dirty_user_xml = storage.mget(key_version,Service.storage_key(service_id, :version),Application.storage_key(service_id,application_id,:version),User.storage_key(service_id,username,:version),cached_app_key,cached_user_key)

            current_version = "s:#{ver_service}/a:#{ver_application}/u:#{ver_user}"
          end

          if !version.nil? && current_version==version
            ## success, we have seen this key combination before, probably shit loads
            ## of times. And neither service, application or user have changed, or any
            ## other object that has a foreing key to service, application or user 
            isknown = true

            # this does not necessarily means that the request is going to be authorized
            # it will depend on getting the status from cache. This means that this keys
            # id's combination has been seen before, and perhaps, has a status stored in
            # in the cache.

          else
            ## something has changed in service, user, application, metric, plan, etc.
            isknown = false
          end
      
        else
          isknown = false
        end

        combination_data = {:key => key_version, :current_version => current_version}

        return [isknown, service_id, combination_data, dirty_app_xml, dirty_user_xml]

      end

      
      def combination_save(data)

        unless data.nil? || data[:key].nil? || data[:current_version].nil?
          storage.pipelined do
            storage.set(data[:key],data[:current_version])
            storage.expire(data[:key],COMBINATION_TTL) 
          end
        end

      end


      ## this one is hacky, handle with care. This updates the cached xml so that we can increment 
      ## the current_usage. TODO: we can do limit checking here, however, the non-cached authrep does not	
      ## cover this corner case either, e.g. it could be that the output is <current_value>101</current_value>
      ## and <max_value>100</max_value> and still be authorized, the next authrep with fail be limits though.
      ## This would have been much more elegant if we were caching serialized objects, but binary marshalling
      ## is extremely slow, divide performance by 2, and marshalling is faster than json, yaml, byml, et
      ## (benchmarked)

      def clean_cached_xml(app_xml_str, user_xml_str, options = {})
 
        if user_xml_str.nil? 
          v = app_xml_str.split("<__separator__/>")
          newxmlstr = ""
          v[0]=="0" ? app_authorized = false : app_authorized = true
          ## better that v.join()
          for i in 1..v.size-1 do
            newxmlstr << v[i].to_s
          end
          xmlstr = newxmlstr
          authorized = app_authorized
        else
          v = app_xml_str.split("<__separator__/>")
          v[0]=="0" ? app_authorized = false : app_authorized = true

          w = user_xml_str.split("<__separator__/>")
          w[0]=="0" ? user_authorized = false : user_authorized = true
        
          ## add the user usage_report segment
          v = v.insert(3,w[2])
          ## change the <status>autho <> segment if the user did not get authorized
          ## if the application was not authorized no problem because it's the default
          ## both need to be authorized, other not authorized. This might produce a collision
          ## on the reasons, but let's assume app has precedence

          v[1]=w[2] if !user_authorized && app_authorized
            
          newxmlstr = ""
          for i in 1..v.size-1 do
            newxmlstr << v[i].to_s
          end
          xmlstr = newxmlstr

          authorized = app_authorized && user_authorized
        end
  
        ## now xmlstr should have the merged status xmls, and authorize should contain whether 
        ## of not it will be authrorized
 
        v = xmlstr.split("|.|")
        newxmlstr = ""
        limit_violation_without_usage = false
        limit_violation_with_usage = false

        i=0
        v.each do |str|
          if (i%2==1)
            type, metric, curr_value, max_value = str.split(",")
            curr_value = curr_value.to_i
            max_value = max_value.to_i
            inc = 0
            inc = options[:usage][metric].to_i unless options[:usage].nil?

            limit_violation_without_usage = (curr_value > max_value) unless limit_violation_without_usage
            limit_violation_with_usage = (curr_value + inc > max_value) unless limit_violation_with_usage

            if authorized && options[:add_usage_on_report]
              ## only increase if asked explicity via options[:add_usage_on_report] and if the status was
              ## authorized to begin with, otherwise we might increment on a status that is not authorized
              ## and that would look weird for the user
              str = (curr_value + inc).to_s
            else
              str = curr_value.to_s
            end
          end

          newxmlstr << str
          i += 1
        end

        if authorized && (limit_violation_without_usage || limit_violation_with_usage)
          ## the cache says that the status was authorized but a violation just occured on the limits... 
          ## then, just forget and let the proper way to calculated
          violation_just_happened = true
        else
          
          violation_just_happened = false
        end



        return [newxmlstr, authorized, violation_just_happened]
      end

      

      ## preemptive_usage is whether or not the usage[] from params needs
      ## to be accounted for in the calculation of the limits
      ## options[:add_usage]=true, add the usage in the result
      ## options[:obey_limits]=true, returns the real status, not from cache, 
      ## if the usage (+ the params[usage] if :add_usage==true) 
      ## are above the max_value
      ## {:add_usage_on_report => true, :add_usage_on_limit_check => false}

      def get_status_in_cache(service_id, application_id, username, options = {}) 
        status = nil

        cached_app_key = caching_key(service_id,:application,application_id)
        is_app_violation = true
        is_user_violation = true


        if username.nil?
          ## case of only application, no user
          #is_app_violation, dirty_app_xml = storage.pipelined do
          #  storage.sismember("limit_violations_set",cached_app_key)
          #  storage.get(cached_app_key)
          #end
          #cached_status_result = !is_app_violation

          if options[:dirty_app_xml].nil?            
            dirty_app_xml = storage.get(cached_app_key) 
          else
            dirty_app_xml = options[:dirty_app_xml]
          end

          if not dirty_app_xml.nil?
            #options[:usage] = usage unless usage.nil? 
            cached_status_xml, cached_status_result, violation_just_happened = clean_cached_xml(dirty_app_xml, nil, options)
            if not violation_just_happened
              return [cached_status_xml, cached_status_result] 
            end
          end

        else
          ## case of application and user

          cached_user_key = caching_key(service_id,:user,username)
          if options[:dirty_app_xml].nil? || options[:dirty_user_xml].nil?
            dirty_app_xml, dirty_user_xml = storage.mget(cached_app_key,cached_user_key) 
          else
            dirty_app_xml = options[:dirty_app_xml]
            dirty_user_xml = options[:dirty_user_xml]
          end

          #cached_user_key = caching_key(service_id,:user,username)
          #is_app_violation, is_user_violation, dirty_app_xml, dirty_user_xml = storage.pipelined do
          #  storage.sismember("limit_violations_set",cached_app_key)
          #  storage.sismember("limit_violations_set",cached_user_key)
          #  storage.get(cached_app_key)
          #  storage.get(cached_user_key)
          #end
          #cached_status_result = !(is_app_violation || is_user_violation)

          if !dirty_app_xml.nil? && !dirty_user_xml.nil? 
            #options[:usage] = usage unless usage.nil?
            cached_status_xml, cached_status_result, violation_just_happened = clean_cached_xml(dirty_app_xml, dirty_user_xml, options)
            if not violation_just_happened
              return [cached_status_xml, cached_status_result]
            end 
          end
        end

        return [nil, nil, nil]

      end

      

      def set_status_in_cache(key, status, options ={})
        options[:anchors_for_caching] = true   
        if status.authorized?
          storage.pipelined do
            storage.set(key,status.to_xml(options))
            storage.expire(key,STATUS_TTL-Time.now.sec)
            storage.srem("limit_violations_set",key)
          end
        else
          ## it just violated the Limits, add to the violation set
          storage.pipelined do 
            storage.set(key,status.to_xml(options))
            storage.expire(key,STATUS_TTL-Time.now.sec)
            storage.sadd("limit_violations_set",key)
          end 
        end
      end

      def caching_key(service_id, type ,id)
        "cache/service:#{service_id}/#{type.to_s}:#{id}"
      end

    end
  end
end
