module ThreeScale
  module Backend
    module Stats
      module KeyPartFormatter
        module TypeFormatter
          attr_reader :service_id
          def initialize(service_id)
            @service_id = service_id
          end
        end

        class ResponseCodeServiceTypeFormatter
          include TypeFormatter

          def get_key(response_code:, period:)
            Stats::Keys.service_response_code_value_key(service_id, response_code, period)
          end
        end

        class ResponseCodeApplicationTypeFormatter
          include TypeFormatter

          def get_key(application:, response_code:, period:)
            Stats::Keys.application_response_code_value_key(service_id, application,
                                                            response_code, period)
          end
        end

        class ResponseCodeUserTypeFormatter
          include TypeFormatter

          def get_key(user:, response_code:, period:)
            Stats::Keys.user_response_code_value_key(service_id, user, response_code, period)
          end
        end

        class UsageServiceTypeFormatter
          include TypeFormatter

          def get_key(metric:, period:)
            Stats::Keys.service_usage_value_key(service_id, metric, period)
          end
        end

        class UsageApplicationTypeFormatter
          include TypeFormatter

          def get_key(metric:, application:, period:)
            Stats::Keys.application_usage_value_key(service_id, application, metric, period)
          end
        end

        class UsageUserTypeFormatter
          include TypeFormatter

          def get_key(metric:, user:, period:)
            Stats::Keys.user_usage_value_key(service_id, user, metric, period)
          end
        end
      end
    end
  end
end
