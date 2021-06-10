require 'json'

module ThreeScale
  module Backend
    module Transactor
      class Status
        # This is the default field we respond with when using OAuth redirects
        # We only use 'redirect_uri' if a request sent such a param. See #397.
        REDIRECT_URI_FIELD = 'redirect_url'.freeze
        private_constant :REDIRECT_URI_FIELD
        # Maximum number of keys to list when using the list_app_keys extension
        # At the time of writing System/Porta has a limit of 5 different app_keys
        # at any given moment, but this could change anytime.
        LIST_APP_KEYS_MAX = 256
        private_constant :LIST_APP_KEYS_MAX

        def initialize(attributes)
          @service_id        = attributes[:service_id]
          @application       = attributes[:application]
          @oauth             = attributes[:oauth]
          @usage             = attributes[:usage]
          @predicted_usage   = attributes[:predicted_usage]
          @values            = filter_values(attributes[:values] || {})
          @timestamp         = attributes[:timestamp] || Time.now.getutc
          @hierarchy_ext     = attributes[:hierarchy]
          @flat_usage_ext    = attributes[:flat_usage]
          @list_app_keys_ext = attributes[:list_app_keys]

          raise 'service_id not specified' if @service_id.nil?
          raise ':application is required' if @application.nil?

          @redirect_uri_field = REDIRECT_URI_FIELD
          @authorized  = true
        end

        attr_reader :service_id
        attr_reader :application
        attr_reader :oauth
        attr_accessor :redirect_uri_field
        attr_accessor :values

        def flat_usage
          @flat_usage_ext
        end

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

        # Returns the actual usage. If there isn't one, returns the predicted
        # usage. If there isn't an actual or predicted usage, returns nil.
        def actual_or_predicted_usage
          usage || predicted_usage
        end

        def authorized?
          @authorized
        end

        def plan_name
          @application.plan_name unless @application.nil?
        end

        def application_usage_reports
          @usage_report ||= load_usage_reports @application
        end

        def value_for_usage_limit(usage_limit)
          values = @values[usage_limit.period]
          values && values[usage_limit.metric_id] || 0
        end

        # provides a hierarchy hash with metrics as symbolic names
        def hierarchy
          @hierarchy ||= Metric.hierarchy service_id
        end

        def limit_headers(now = Time.now.utc)
          # maybe filter by exceeded reports if not authorized
          LimitHeaders.get(reports_to_calculate_limit_headers, now)
        end

        def to_xml(options = {})
          xml = ''
          xml << '<?xml version="1.0" encoding="UTF-8"?>'.freeze unless options[:skip_instruct]
          xml << '<status>'.freeze

          add_authorize_section(xml)

          if oauth
            add_application_section(xml)
          end

          hierarchy_reports = [] if @hierarchy_ext
          if !@application.nil?
            add_plan_section(xml, 'plan'.freeze, plan_name)
            add_reports_section(xml, application_usage_reports)
            hierarchy_reports.concat application_usage_reports if hierarchy_reports
            add_app_keys_section xml if @list_app_keys_ext
          end

          if hierarchy_reports
            add_hierarchy_section(xml, hierarchy_reports)
          end

          xml << '</status>'.freeze
        end

        private

        # Returns the app usage reports needed to construct the limit headers.
        # If the status does not have a 'usage', this method returns all the
        # usage reports. Otherwise, it returns the reports associated with the
        # metrics present in the 'usage' and their parents.
        def reports_to_calculate_limit_headers
          all_reports = application_usage_reports

          return all_reports if (@usage.nil? || @usage.empty?)

          metric_names_in_usage = @usage.keys
          metrics = metric_names_in_usage | ascendants_names(metric_names_in_usage)
          all_reports.select { |report| metrics.include?(report.metric_name) }
        end

        def ascendants_names(metric_names)
          metric_names.flat_map do |metric_name|
            Metric.ascendants(@service_id, metric_name)
          end
        end

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

        def add_hierarchy_section(xml, reports)
          xml << '<hierarchy>'.freeze
          with_report_and_hierarchy(reports) do |ur, children|
            xml << '<metric name="'.freeze
            xml << ur.metric_name << '" children="'.freeze
            xml << (children ? children.join(' '.freeze) : '') << '"/>'.freeze
          end
          xml << '</hierarchy>'.freeze
        end

        def add_app_keys_section(xml)
          xml << '<app_keys app="'.freeze
          xml << @application.id << '" svc="'.freeze
          xml << @service_id << '">'.freeze
          @application.keys.take(LIST_APP_KEYS_MAX).each do |key|
            xml << '<key id="'.freeze
            xml << key << '"/>'.freeze
          end
          xml << '</app_keys>'.freeze
        end

        # helper to iterate over reports and get relevant hierarchy info
        def with_report_and_hierarchy(reports)
          reports.each do |ur|
            yield ur, hierarchy[ur.metric_name]
          end
        end

        def add_plan_section(xml, tag, plan_name)
          xml << "<#{tag}>"
          xml << plan_name.to_s.encode(xml: :text) << "</#{tag}>"
        end

        def add_authorize_section(xml)
          if authorized?
            xml << '<authorized>true</authorized>'.freeze
          else
            xml << '<authorized>false</authorized><reason>'.freeze
            xml << rejection_reason_text
            xml << '</reason>'.freeze
          end
        end

        def add_application_section(xml)
          redirect_uri = application.redirect_url
          xml << '<application>' \
                 "<id>#{application.id}</id>" \
                 "<key>#{application.keys.first}</key>" \
                 "<#{@redirect_uri_field}>#{redirect_uri}</#{@redirect_uri_field}>" \
                 '</application>'
        end

        def load_usage_reports(application)
          # We might have usage limits that apply to metrics that no longer
          # exist. In that case, the usage limit refers to a metric ID that no
          # longer has a name associated to it. When that happens, we do not
          # want to take into account that usage limit.
          # This might happen, for example, when a Backend client decides to delete
          # a metric and all the associated usage limits, but the operation fails
          # for some of the usage limits.

          reports = []
          if !application.nil?
            application.usage_limits.each do |usage_limit|
              if application.metric_name(usage_limit.metric_id)
                reports << UsageReport.new(self, usage_limit)
              end
            end
          end
          reports
        end

        def add_reports_section(xml, reports)
          unless reports.empty?
            xml_node = 'usage_reports>'.freeze
            xml << '<'.freeze
            xml << xml_node
            reports.each do |report|
              xml << report.to_xml
            end
            xml << '</'.freeze
            xml << xml_node
          end
        end

      end
    end
  end
end
