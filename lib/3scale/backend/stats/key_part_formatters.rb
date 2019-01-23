module ThreeScale
  module Backend
    module Stats
      module KeyPartFormatter
        class ResponseCodeServiceTypeFormatter
          def get_key(service:, response_code:, period:)
            Stats::Keys.service_response_code_value_key(service, response_code, period)
          end
        end

        class ResponseCodeApplicationTypeFormatter
          def get_key(service:, application:, response_code:, period:)
            Stats::Keys.application_response_code_value_key(service, application,
                                                            response_code, period)
          end
        end

        class ResponseCodeUserTypeFormatter
          def get_key(service:, user:, response_code:, period:)
            Stats::Keys.user_response_code_value_key(service, user, response_code, period)
          end
        end

        class UsageServiceTypeFormatter
          def get_key(service:, metric:, period:)
            Stats::Keys.service_usage_value_key(service, metric, period)
          end
        end

        class UsageApplicationTypeFormatter
          def get_key(service:, metric:, application:, period:)
            Stats::Keys.application_usage_value_key(service, application, metric, period)
          end
        end

        class UsageUserTypeFormatter
          def get_key(service:, metric:, user:, period:)
            Stats::Keys.user_usage_value_key(service, user, metric, period)
          end
        end
      end
    end
  end
end
