require 'json'

module ThreeScale
  module Backend
    module Transactor
      class Status
        # This is the default field we respond with when using OAuth redirects
        # We only use 'redirect_uri' if a request sent such a param. See #397.
        REDIRECT_URI_FIELD = 'redirect_url'.freeze
        private_constant :REDIRECT_URI_FIELD

        def initialize(attributes)
          @service_id      = attributes[:service_id]
          @application     = attributes[:application]
          @oauth           = attributes[:oauth]
          @usage           = attributes[:usage]
          @predicted_usage = attributes[:predicted_usage]
          @values          = filter_values(attributes[:values] || {})
          @user            = attributes[:user]
          @user_values     = filter_values(attributes[:user_values])
          @timestamp       = attributes[:timestamp] || Time.now.getutc
          @hierarchy_ext   = attributes[:hierarchy]

          raise 'service_id not specified' if @service_id.nil?
          raise ':application is required' if @application.nil? && @user.nil?

          @redirect_uri_field = REDIRECT_URI_FIELD
          @authorized  = true
        end

        attr_reader :service_id
        attr_reader :application
        attr_reader :oauth
        attr_accessor :redirect_uri_field
        attr_accessor :values
        attr_reader :user
        attr_accessor :user_values

        def reject!(error)
          @authorized = false
          @rejection_reason_code ||= error.code
          @rejection_reason_text ||= error.message
        end

        attr_reader :timestamp
        attr_reader :rejection_reason_code
        attr_reader :rejection_reason_text

        # Returns the usage to be reported in an authrep request.
        def usage
          @predicted_usage ? nil : @usage
        end

        # Returns the predicted usage of an authorize request.
        def predicted_usage
          @predicted_usage ? @usage : nil
        end

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

        def application_usage_reports
          @usage_report ||= load_usage_reports @application, :application
        end

        def user_usage_reports
          @user_usage_report ||= load_usage_reports @user, :user
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

        # provides a hierarchy hash with metrics as symbolic names
        def hierarchy
          @hierarchy ||= Metric.hierarchy service_id
        end

        def to_xml(options = {})
          xml = ''
          xml << '<?xml version="1.0" encoding="UTF-8"?>'.freeze unless options[:skip_instruct]
          xml << '<status><authorized>'.freeze

          if authorized?
            xml << 'true</authorized>'.freeze
          else
            xml << 'false</authorized><reason>'.freeze
            xml << rejection_reason_text
            xml << '</reason>'.freeze
          end

          if oauth
            redirect_uri = application.redirect_url
            xml << '<application>' \
                   "<id>#{application.id}</id>" \
                   "<key>#{application.keys.first}</key>" \
                   "<#{@redirect_uri_field}>#{redirect_uri}</#{@redirect_uri_field}>" \
                   '</application>'
            if !@user.nil?
              xml << "<user><id>#{@user.username}</id></user>"
            end
          end

          hierarchy_reports = [] if @hierarchy_ext
          if !@application.nil? && !options[:exclude_application]
            add_plan(xml, 'plan'.freeze, plan_name)
            xml << aux_reports_to_xml(application_usage_reports)
            hierarchy_reports.concat application_usage_reports if hierarchy_reports
          end
          if !@user.nil? && !options[:exclude_user]
            add_plan(xml, 'user_plan'.freeze, user_plan_name)
            xml << aux_reports_to_xml(user_usage_reports, true)
            hierarchy_reports.concat user_usage_reports if hierarchy_reports
          end

          if hierarchy_reports
            add_hierarchy(xml, hierarchy_reports)
          end

          xml << '</status>'.freeze
        end

        private

        # make sure the keys are Periods
        def filter_values(values)
          return nil if values.nil?
          values.inject({}) do |acc, (k, v)|
            key = begin
                    Period[k]
                  rescue Period::Unknown
                    k
                  end
            acc[key] = v
            acc
          end
        end

        def add_hierarchy(xml, reports)
          xml << '<hierarchy>'.freeze
          with_report_and_hierarchy(reports) do |ur, children|
            xml << '<metric name="'.freeze
            xml << ur.metric_name << '" children="'.freeze
            xml << (children ? children.join(' '.freeze) : '') << '"/>'.freeze
          end
          xml << '</hierarchy>'.freeze
        end

        # helper to iterate over reports and get relevant hierarchy info
        def with_report_and_hierarchy(reports)
          reports.each do |ur|
            yield ur, hierarchy[ur.metric_name]
          end
        end

        def add_plan(xml, tag, plan_name)
          xml << "<#{tag}>"
          xml << plan_name.to_s.encode(xml: :text) << "</#{tag}>"
        end

        def load_usage_reports(what, type)
          # We might have usage limits that apply to metrics that no longer
          # exist. In that case, the usage limit refers to a metric ID that no
          # longer has a name associated to it. When that happens, we do not
          # want to take into account that usage limit.
          # This might happen, for example, when a Backend client decides to delete
          # a metric and all the associated usage limits, but the operation fails
          # for some of the usage limits.

          reports = []
          if !what.nil?
            what.usage_limits.each do |usage_limit|
              if what.metric_name(usage_limit.metric_id)
                reports << UsageReport.new(self, usage_limit, type)
              end
            end
          end
          reports
        end

        def aux_reports_to_xml(reports, report_type_user = false)
          xml = ''
          unless reports.empty?
            xml_node = if report_type_user
                         'user_usage_reports>'.freeze
                       else
                         'usage_reports>'.freeze
                       end
            xml << '<'.freeze
            xml << xml_node
            reports.each do |report|
              xml << report.to_xml
            end
            xml << '</'.freeze
            xml << xml_node
          end

          xml
        end

      end
    end
  end
end
