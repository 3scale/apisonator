module ThreeScale
  module Backend
    module Stats
      class KeyGenerator
        attr_reader :service_id, :applications, :metrics, :users, :from, :to

        def initialize(service_id:, applications: [], metrics: [], users: [], from:, to:, **)
          @service_id = service_id
          @applications = applications
          @metrics = metrics
          @users = users
          @from = from
          @to = to
        end

        def keys
          Enumerator.new do |y|
            response_code_service_keys.each { |e| y << e }
            response_code_application_keys.each { |e| y << e }
            response_code_user_keys.each { |e| y << e }
            usage_service_keys.each { |e| y << e }
            usage_application_keys.each { |e| y << e }
            usage_user_keys.each { |e| y << e }
          end
        end

        private

        def period_range(granularity)
          Period[granularity].new(Time.at(from))..Period[granularity].new(Time.at(to))
        end

        def periods(granularities)
          Enumerator.new do |y|
            granularities.each do |gr|
              period_range(gr).each do |period|
                y << period
              end
            end
          end
        end

        def response_codes
          CodesCommons::TRACKED_CODES + CodesCommons::TRACKED_CODE_GROUPS
        end

        def response_code_service_keys
          Enumerator.new do |y|
            periods(PeriodCommons::PERMANENT_SERVICE_GRANULARITIES).each do |period|
              response_codes.each do |response_code|
                y << Keys.service_response_code_value_key(service_id, response_code, period)
              end
            end
          end
        end

        def response_code_application_keys
          Enumerator.new do |y|
            periods(PeriodCommons::PERMANENT_EXPANDED_GRANULARITIES).each do |period|
              response_codes.each do |response_code|
                applications.each do |application|
                  y << Keys.application_response_code_value_key(service_id, application,
                                                                response_code, period)
                end
              end
            end
          end
        end

        def response_code_user_keys
          Enumerator.new do |y|
            periods(PeriodCommons::PERMANENT_EXPANDED_GRANULARITIES).each do |period|
              response_codes.each do |response_code|
                users.each do |user|
                  y << Keys.user_response_code_value_key(service_id, user, response_code, period)
                end
              end
            end
          end
        end

        def usage_service_keys
          Enumerator.new do |y|
            periods(PeriodCommons::PERMANENT_SERVICE_GRANULARITIES).each do |period|
              metrics.each do |metric|
                y << Keys.service_usage_value_key(service_id, metric, period)
              end
            end
          end
        end

        def usage_application_keys
          Enumerator.new do |y|
            periods(PeriodCommons::PERMANENT_EXPANDED_GRANULARITIES).each do |period|
              metrics.each do |metric|
                applications.each do |application|
                  y << Keys.application_usage_value_key(service_id, application, metric, period)
                end
              end
            end
          end
        end

        def usage_user_keys
          Enumerator.new do |y|
            periods(PeriodCommons::PERMANENT_EXPANDED_GRANULARITIES).each do |period|
              users.each do |user|
                metrics.each do |metric|
                  y << Keys.user_usage_value_key(service_id, user, metric, period)
                end
              end
            end
          end
        end
      end
    end
  end
end
