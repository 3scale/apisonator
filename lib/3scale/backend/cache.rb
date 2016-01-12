require '3scale/backend/errors'

module ThreeScale
  module Backend
    # Methods for caching
    module Cache
      include Backend::StorageKeyHelpers
      extend self

      VALID_PARAMS_FOR_CACHE = [:provider_key,
                                :service_id,
                                :app_id,
                                :app_key,
                                :user_key,
                                :user_id,
                                :referrer,
                                :redirect_url,
                                :redirect_uri,
                                :usage]

      COMBINATION_TTL       = 3600 # 1 hour
      STATUS_TTL            = 60   # 1 minute, this is too short but we need minute information on the output :-(
      SERVICE_ID_CACHE_TTL  = 300  # 5 minutes

      def stats
        @@stats ||= {:count => 0, :hits => 0, :last => nil}
        @@stats
      end

      def stats=(s)
        @@stats=s
      end

      def report_cache_hit
        @@stats ||= {:count => 0, :hits => 0, :last => nil}
        @@stats[:count]+=1
        @@stats[:hits]+=1
        @@stats[:last]=1
      end

      def report_cache_miss
        @@stats ||= {:count => 0, :hits => 0, :last => nil}
        @@stats[:count]+=1
        @@stats[:last]=0
      end

      def caching_enable
        storage.set("settings/caching_enabled",1)
      end

      def caching_disable
        storage.set("settings/caching_enabled",0)
      end

      def caching_enabled?
        storage.get("settings/caching_enabled")!="0"
      end

      def signature(action, params)
        key_version = "cache_combination/#{action}/"
        usage = params[:usage]

        VALID_PARAMS_FOR_CACHE.each do |label|
          if label != :usage || usage.nil?
            key_version << "#{label}:#{params[label]}/"
          else
            usage.each do |key, value|
              key_version << "#{label}:#{key}:"
            end
          end
        end
        key_version
      end

      def combination_seen(action, provider_key, params)
        key_version = nil

        if params[:service_id].nil? || params[:service_id].empty?
          #memoizing provider_key by service_id is no longer possible, because it can
          #change in the meantime, extremely unconvenient
          service_id = Service.default_id!(provider_key)
        else
          service_id = params[:service_id]
        end

        isknown = if service_id
          key_version = signature(action, params)

          application_id = params[:app_id] || params[:user_key] || ''

          application_id_cached = application_id.clone
          application_id_cached << ":"
          application_id_cached << params[:app_key] unless params[:app_key].nil?
          application_id_cached << ":"
          application_id_cached << params[:referrer] unless params[:referrer].nil?

          # FIXME: this needs to be done for redirect_url(??)

          mget_query = [
            key_version,
            Service.storage_key(service_id, :version),
            Application.storage_key(service_id, application_id, :version),
            caching_key(service_id, :application, application_id_cached),
            "settings/caching_enabled"
          ]

          username = params[:user_id]

          mget_query.push(User.storage_key(service_id, username, :version),
                          caching_key(service_id, :user, username)) if username

          version,
          ver_service,
          ver_application,
          dirty_app_xml,
          caching_enabled,
          ver_user,
          dirty_user_xml = storage.mget mget_query

          current_version = "s:#{ver_service}/a:#{ver_application}"
          current_version += "/u:#{ver_user}" if ver_user

          ## if success, we have seen this key combination before, probably shit loads
          ## of times. And neither service, application or user have changed, or any
          ## other object that has a foreing key to service, application or user

          # this does not necessarily means that the request is going to be authorized
          # it will depend on getting the status from cache. This means that this keys
          # id's combination has been seen before, and perhaps, has a status stored in
          # in the cache.

          ## else something has changed in service, user, application, metric, plan, etc.
          current_version == version
        else
          # not known
          false
        end

        combination_data = {:key => key_version, :current_version => current_version}

        ## the default of settings/caching_enabled results on true, to disable caching set
        ## settings/caching_enabled to 0
        caching_enabled = caching_enabled != "0"

        [isknown, service_id, combination_data, dirty_app_xml, dirty_user_xml, caching_enabled]
      end

      def combination_save(data)
        unless data.nil? || data[:key].nil? || data[:current_version].nil?
          storage.pipelined do
            storage.set(data[:key], data[:current_version])
            storage.expire(data[:key], COMBINATION_TTL)
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
        split_app_xml  = split_xml(app_xml_str)
        split_user_xml = split_xml(user_xml_str)
        authorized     = xml_authorized?(split_app_xml, split_user_xml)
        merged_xml     = merge_xmls(authorized, split_app_xml, split_user_xml)

        v = merged_xml.split("|.|")
        newxmlstr = ""
        limit_violation_without_usage = false
        limit_violation_with_usage = false

        v.each_slice(2) do |uninteresting, str|
          newxmlstr << uninteresting

          if str
            _, metric, curr_value, max_value = str.split(",")
            curr_value = curr_value.to_i
            max_value = max_value.to_i
            inc = 0
            val = nil

            if options[:usage]
              inc = options[:usage][metric].to_i
              val = Helpers.get_value_of_set_if_exists(options[:usage][metric])
            end

            limit_violation_without_usage ||= curr_value > max_value
            limit_violation_with_usage ||=
              if val
                val.to_i > max_value
              elsif inc > 0
                curr_value + inc > max_value
              end

            newxmlstr <<
              if authorized && options[:add_usage_on_report]
                ## only increase if asked explicity via options[:add_usage_on_report] and if the status was
                ## authorized to begin with, otherwise we might increment on a status that is not authorized
                ## and that would look weird for the user
                if val.nil?
                  curr_value + inc
                else
                  val
                end
              else
                curr_value
              end.to_s
          end
        end

        # a violation on the limits with usage depends on whether status is authorized
        # if no violation with usage, just look if we have a violation wo usage
        # if we end up with a violation, forget the cache and compute it properly
        violation = if limit_violation_with_usage
          authorized
        else
          limit_violation_without_usage
        end

        [newxmlstr, authorized, violation]
      end


      ## sets all the application by id:app_key
      def set_status_in_cache_application(service_id, application, status, options ={})
        options[:anchors_for_caching] = true
        content = status.to_xml(options)
        tmp_keys = []
        keys = []

        application.keys.each do |app_key|
          tmp_keys << "#{application.id}:#{app_key}"
        end

        tmp_keys << "#{application.id}:" if application.keys.empty?

        application.referrer_filters.each do |referrer|
          tmp_keys.each do |item|
            keys << caching_key(service_id,:application,"#{item}:#{referrer}")
          end
        end

        if application.referrer_filters.empty?
          tmp_keys.each do |item|
            keys << caching_key(service_id,:application,"#{item}:")
          end
        end

        store_keys_in_cache(status, keys, content)
      end

      def set_status_in_cache(key, status, options ={})
        options[:anchors_for_caching] = true
        store_keys_in_cache(status, [key], status.to_xml(options))
      end

      def caching_key(service_id, type ,id)
        "cache/service:#{service_id}/#{type.to_s}:#{id}"
      end

      def update_status_cache(applications, users = {})
        current_timestamp = Time.now.getutc

        applications.each do |_appid, values|
          application = Application.load(values[:service_id], values[:application_id])
          usage  = ThreeScale::Backend::Transactor.send(:load_application_usage, application, current_timestamp)
          status = ThreeScale::Backend::Transactor::Status.new(application: application, values: usage)
          ThreeScale::Backend::Validators::Limits.apply(status, {})

          max_utilization, max_record = ThreeScale::Backend::Alerts.utilization(status)
          if max_utilization >= 0.0
            ThreeScale::Backend::Alerts.update_utilization(status, max_utilization, max_record, current_timestamp)
          end

          ThreeScale::Backend::Cache.set_status_in_cache_application(values[:service_id], application, status, exclude_user: true)
        end

        users.each do |_userid, values|
          service ||= Service.load_by_id(values[:service_id])
          if service.id != values[:service_id]
            raise ServiceLoadInconsistency.new(values[:service_id], service.id)
          end
          user   = User.load_or_create!(service, values[:user_id])
          usage  = ThreeScale::Backend::Transactor.send(:load_user_usage, user, current_timestamp)
          status = ThreeScale::Backend::Transactor::Status.new(user: user, user_values: usage)
          ThreeScale::Backend::Validators::Limits.apply(status, {})

          key = ThreeScale::Backend::Cache.caching_key(service.id, :user, user.username)
          ThreeScale::Backend::Cache.set_status_in_cache(key, status, exclude_application: true)
        end
      end

      private

      def store_keys_in_cache(status, keys, content)
        now = Time.now.getutc.sec
        op = status.authorized? ? :srem : :sadd
        storage.pipelined do
          keys.each do |key|
            storage.set(key, content)
            storage.expire(key, STATUS_TTL - now)
            storage.send op, 'limit_violations_set', key
          end
        end
      end

      def split_xml(xml_str)
        xml_str.split("<__separator__/>") if xml_str
      end

      def xml_authorized?(split_app_xml, split_user_xml = nil)
        # a node is authorized if it is != '0'
        split_app_xml.first != '0' &&
          (split_user_xml.nil? || split_user_xml.first != '0')
      end

      def merge_xmls(authorized, split_app_xml, split_user_xml = nil)
        if split_user_xml
          ## add the user usage_report segment
          split_app_xml    = split_app_xml.insert(3, split_user_xml[2])
          ## change the <status>autho <> segment if the user did not get
          ## authorized if the application was not authorized no problem
          ## because it's the default both need to be authorized, other
          ## not authorized. This might produce a collision on the reasons,
          ## but let's assume app has precedence
          split_app_xml[1] = split_user_xml[1]
        end

        ## better that v.join()
        result = ""
        (1...split_app_xml.size).each do |i|
          result << split_app_xml[i].to_s
        end

        result
      end

      def storage
        Storage.instance
      end
    end
  end
end
