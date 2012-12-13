require 'json'

module ThreeScale
  module Backend
    module Transactor
      class Status
        class UsageReport
          def initialize(parent, usage_limit, type)
            @parent      = parent
            @usage_limit = usage_limit
            @type        = type
          end

          def metric_name
            name = nil
            if @type==:application
              name = @parent.application.metric_name(@usage_limit.metric_id)
            else
              name = @parent.user.metric_name(@usage_limit.metric_id)
            end
            name
          end

          def period
            @usage_limit.period
          end

          def period_start
            @parent.timestamp.beginning_of_cycle(period)
          end

          def period_end
            @parent.timestamp.end_of_cycle(period)
          end

          def max_value
            @usage_limit.value
          end

          def current_value
            @parent.value_for_usage_limit(@usage_limit,@type)
          end

          def exceeded?
            current_value > max_value
          end

          def inspect
            "#<#{self.class.name} period=#{period}" +
            " metric_name=#{metric_name}" +
            " max_value=#{max_value}" +
            " current_value=#{current_value}>"
          end
        end

        def initialize(attributes = {})
          @service     = attributes[:service]
          @application = attributes[:application] 
          @values      = attributes[:values] || {}
          @user        = attributes[:user]
          @user_values = attributes[:user_values]
          @timestamp   = attributes[:timestamp] || Time.now.getutc

          if (@application.nil? and @user.nil?) 
            raise ':application is required'
          end

          @authorized  = true
        end

        attr_reader :service
        attr_accessor :application
        attr_accessor :values
        attr_reader :predicted_values
        attr_accessor :user
        attr_accessor :user_values  

        def reject!(error)
          @authorized = false
          @rejection_reason_code ||= error.code
          @rejection_reason_text ||= error.message
        end

        attr_reader :timestamp
        attr_reader :rejection_reason_code
        attr_reader :rejection_reason_text

        def authorized? 
          @authorized
        end

        def plan_name
          @application.plan_name unless @application.nil?
        end

        def application_plan_name
           plan_name 
        end

       	def user_plan_name
          @user.plan_name unless @user.nil?
        end

        def usage_reports
          application_usage_reports
        end

        def application_usage_reports
          @usage_report ||= load_application_usage_reports
        end

        def user_usage_reports
          @user_usage_report ||= load_user_usage_reports
        end
          

        def value_for_usage_limit(usage_limit, type = :application)
          if type==:application
            values = @values[usage_limit.period]
          else
            values = @user_values[usage_limit.period]
          end
          values && values[usage_limit.metric_id] || 0
        end

        def value_for_application_usage_limit(usage_limit)
          values = @values[usage_limit.period]
          values && values[usage_limit.metric_id] || 0
        end

        def value_for_user_usage_limit(usage_limit)
          values = @user_values[usage_limit.period]
          values && values[usage_limit.metric_id] || 0
        end


        ## WARNING/CAUTION: any change in to_xml must be reflected in cache.rb/clean_cached_xml !!!
        
        
        def to_my_xml(options = {})
          
          xml = ""
          
          xml << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" unless options[:skip_instruct]
          
          xml << "<status>"
          
          if authorized? 
            xml << "<authorized>true</authorized>"
          else
            xml << "<authorized>false</authorized><reason>" << rejection_reason_text << "</reason>"
          end
          
          if options[:oauth]
            xml << "<application>"
            xml << "<id>" << application.id << "</id>"
            xml << "<key>" << application.keys.first << "</key>"
            xml << "<redirect_url>" << application.redirect_url << "</redirect_url>"
            xml << "</application>"
          end
                    
          if @user.nil?
          
            xml << "<__separator__/>" if options[:anchors_for_caching]
            xml << "<plan>" << plan_name << "</plan>"
            
            unless application_usage_reports.empty?
              xml << "<usage_reports>"
              application_usage_reports.each do |report|
                attributes = "metric=\"#{report.metric_name}\" period=\"#{report.period}\""
                attributes << " exceeded=\"true\"" if report.exceeded?
                xml << "<usage_report #{attributes}>"
                
                if report.period != :eternity
                  xml << "<period_start>" << report.period_start.strftime(TIME_FORMAT) << "</period_start>"
                  xml << "<period_end>" << report.period_end.strftime(TIME_FORMAT) << "</period_end>"
                end
                xml << "<max_value>" << report.max_value.to_s << "</max_value>"
                
                if not options[:anchors_for_caching]
                	if authorized? && !options[:usage].nil? && !options[:usage][report.metric_name].nil? 
                	  # this is a authrep request and therefore we should sum the usage
                	  val = ThreeScale::Backend::Aggregator::get_value_of_set_if_exists(options[:usage][report.metric_name])
                    if val.nil?
                      xml << "<current_value>" << (report.current_value + options[:usage][report.metric_name].to_i).to_s << "</current_value>"
                    else
                      xml << "<current_value>" << val.to_s << "</current_value>"
                    end
                	else 
                    xml << "<current_value>" << report.current_value.to_s << "</current_value>"
                  end
                else
                  ## this is a hack to avoid marshalling status for caching, this way is much faster, but nastier
                  ## see Transactor.clean_cached_xml(xmlstr, options = {}) for futher info
                  xml << "<current_value>" << "|.|application,#{report.metric_name},#{report.current_value},#{report.max_value}|.|" << "</current_value>"
                end
                
                xml << "</usage_report>"
              end
              xml << "</usage_reports>"
            end
            
          end
           
          xml << "<__separator__/>" if options[:anchors_for_caching]
                      
          xml << "</status>"
          
          if options[:anchors_for_caching]
            ## little hack to avoid parsing for <authorized> to know the state. Not very nice but leave it like this.
            s = authorized? ? "1<__separator__/>" : "0<__separator__/>"
            s << xml
            return s
          else
            return xml
          end
          
        end
        
        def to_xml(options = {})
         
          xml = Builder::XmlMarkup.new
          xml.instruct! unless options[:skip_instruct]
          
          xml.status do
            xml.authorized authorized? ? 'true' : 'false'
            xml.reason     rejection_reason_text unless authorized?

            if options[:oauth]
              xml.application do
                xml.id           application.id
                xml.key          application.keys.first
                xml.redirect_url application.redirect_url
              end
            end

            if @user.nil?

              xml.__separator__ if options[:anchors_for_caching]
              xml.plan       plan_name
              unless application_usage_reports.empty?
                xml.usage_reports do
                  application_usage_reports.each do |report|
                    attributes = {:metric => report.metric_name,
                                  :period => report.period}
                    attributes[:exceeded] = 'true' if report.exceeded?

                    xml.usage_report(attributes) do
                      xml.period_start  report.period_start.strftime(TIME_FORMAT) unless report.period == :eternity
                      xml.period_end    report.period_end.strftime(TIME_FORMAT) unless report.period == :eternity
                      xml.max_value     report.max_value

                      if not options[:anchors_for_caching]
                      	if authorized? && !options[:usage].nil? && !options[:usage][report.metric_name].nil? 
                      	  # this is a authrep request and therefore we should sum the usage
                      	  val = ThreeScale::Backend::Aggregator::get_value_of_set_if_exists(options[:usage][report.metric_name])
                          if val.nil?
                            xml.current_value report.current_value + options[:usage][report.metric_name].to_i
                          else
                            xml.current_value val.to_s
                          end
                      	else 
                          xml.current_value report.current_value
                        end
                      else
                        ## this is a hack to avoid marshalling status for caching, this way is much faster, but nastier
                        ## see Transactor.clean_cached_xml(xmlstr, options = {}) for futher info
                        xml.current_value "|.|application,#{report.metric_name},#{report.current_value},#{report.max_value}|.|"
                      end
                    end
                  end
                end
              end
              
            else

              if !@application.nil? && !options[:exclude_application]  
                xml.__separator__ if options[:anchors_for_caching]
                xml.plan  plan_name unless plan_name.nil?
                unless application_usage_reports.empty? 
                  xml.usage_reports do
                    application_usage_reports.each do |report|
                      attributes = {:metric => report.metric_name, :period => report.period}
                      attributes[:exceeded] = 'true' if report.exceeded?
                      xml.usage_report(attributes) do
                        xml.period_start  report.period_start.strftime(TIME_FORMAT) unless report.period == :eternity
                        xml.period_end    report.period_end.strftime(TIME_FORMAT) unless report.period == :eternity
                        xml.max_value     report.max_value

                        if not options[:anchors_for_caching]
                          if authorized? && !options[:usage].nil? && !options[:usage][report.metric_name].nil? 
                            # this is a authrep request and therefore we should sum the usage
                            val = ThreeScale::Backend::Aggregator::get_value_of_set_if_exists(options[:usage][report.metric_name])
                            if val.nil?
                              xml.current_value report.current_value + options[:usage][report.metric_name].to_i
                            else
                              xml.current_value val.to_s
                            end
                          else 
                            xml.current_value report.current_value
                          end
                        else
                          ## this is a hack to avoid marshalling status for caching, this way is much faster, but nastier
                          ## see Transactor.clean_cached_xml(xmlstr, options = {}) for futher info
                          xml.current_value "|.|application,#{report.metric_name},#{report.current_value},#{report.max_value}|.|"
                        end
                      end
                    end
                  end
                end
              end

              if !@user.nil? && !options[:exclude_user]
                xml.__separator__ if options[:anchors_for_caching]
                xml.user_plan user_plan_name
                unless user_usage_reports.empty?
                  ##attributes = {:from => "user"}
                  ##xml.usage_reports(attributes) do
                  xml.user_usage_reports do
                    user_usage_reports.each do |report|
                      attributes = {:metric => report.metric_name, :period => report.period}
                      attributes[:exceeded] = 'true' if report.exceeded?

                      xml.usage_report(attributes) do
                        xml.period_start  report.period_start.strftime(TIME_FORMAT) unless report.period == :eternity
                        xml.period_end    report.period_end.strftime(TIME_FORMAT) unless report.period == :eternity
                        xml.max_value     report.max_value

                        if not options[:anchors_for_caching] 
                          if authorized? && !options[:usage].nil? && !options[:usage][report.metric_name].nil? 
                            # this is a authrep request and therefore we should sum the usage or set it
                            val = ThreeScale::Backend::Aggregator::get_value_of_set_if_exists(options[:usage][report.metric_name])
                            if val.nil?
                              xml.current_value report.current_value + options[:usage][report.metric_name].to_i
                            else
                              xml.current_value val.to_s
                            end
                          else 
                            xml.current_value report.current_value
                          end
                        else
                          ## this is a hack to avoid marshalling status for caching, this way is much faster, but nastier
                          ## see Transactor.clean_cached_xml(xmlstr, options = {}) for futher info
                          xml.current_value "|.|user,#{report.metric_name},#{report.current_value},#{report.max_value}|.|"
                        end
                      end
                    end
                  end
                end
              end
            end

            xml.__separator__ if options[:anchors_for_caching]
          end

          if options[:anchors_for_caching]
            ## little hack to avoid parsing for <authorized> to know the state. Not very nice but leave it like this.
            
            s = authorized? ? "1<__separator__/>" : "0<__separator__/>"
            s << xml.target!
            return s
          else
            return xml.target!
          end
          
        end

        
        private

        def load_application_usage_reports
          return [] if @application.nil?
          @application.usage_limits.map do |usage_limit|
            UsageReport.new(self, usage_limit, :application)
          end
        end

        def load_user_usage_reports
          return [] if @user.nil?
          @user.usage_limits.map do |usage_limit|
            UsageReport.new(self, usage_limit, :user)
          end
        end
      end
    end
  end
end
