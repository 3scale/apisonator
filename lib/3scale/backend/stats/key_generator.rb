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
          response_code_service_keys +
            response_code_application_keys +
            response_code_user_keys +
            usage_service_keys +
            usage_application_keys +
            usage_user_keys
        end

        private

        def periods(granularities)
          granularities.flat_map do |granularity|
            (Period[granularity].new(Time.at(from))..Period[granularity].new(Time.at(to))).to_a
          end
        end

        def response_codes
          CodesCommons::TRACKED_CODES + CodesCommons::HTTP_CODE_GROUPS_MAP.values
        end

        def response_code_service_keys
          periods(PeriodCommons::PERMANENT_SERVICE_GRANULARITIES).flat_map do |period|
            response_codes.flat_map do |response_code|
              Keys.service_response_code_value_key(service_id, response_code, period)
            end
          end
        end

        def response_code_application_keys
          periods(PeriodCommons::PERMANENT_EXPANDED_GRANULARITIES).flat_map do |period|
            response_codes.flat_map do |response_code|
              applications.flat_map do |application|
                Keys.application_response_code_value_key(service_id, application,
                                                         response_code, period)
              end
            end
          end
        end

        def response_code_user_keys
          periods(PeriodCommons::PERMANENT_EXPANDED_GRANULARITIES).flat_map do |period|
            response_codes.flat_map do |response_code|
              users.flat_map do |user|
                Keys.user_response_code_value_key(service_id, user, response_code, period)
              end
            end
          end
        end

        def usage_service_keys
          periods(PeriodCommons::PERMANENT_SERVICE_GRANULARITIES).flat_map do |period|
            metrics.flat_map do |metric|
              Keys.service_usage_value_key(service_id, metric, period)
            end
          end
        end

        def usage_application_keys
          periods(PeriodCommons::PERMANENT_EXPANDED_GRANULARITIES).flat_map do |period|
            metrics.flat_map do |metric|
              applications.flat_map do |application|
                Keys.application_usage_value_key(service_id, application, metric, period)
              end
            end
          end
        end

        def usage_user_keys
          periods(PeriodCommons::PERMANENT_EXPANDED_GRANULARITIES).flat_map do |period|
            users.flat_map do |user|
              metrics.flat_map do |metric|
                Keys.user_usage_value_key(service_id, user, metric, period)
              end
            end
          end
        end
      end
    end
  end
end
