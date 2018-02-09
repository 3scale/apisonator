require '3scale/backend/logging/middleware/writer'

module ThreeScale
  module Backend
    module Logging
      class Middleware
        class TextWriter
          include Middleware::Writer

          FORMAT = "%s - %s [%s] \"%s %s%s %s\" %d %s %s 0 0 0 %s %s %s %s %s\n".freeze
          private_constant :FORMAT

          ERROR_FORMAT = "%s - %s [%s] \"%s %s%s %s\" %d \"%s\" %s %s %s\n".freeze
          private_constant :ERROR_FORMAT

          SORTED_LOG_FIELDS = [:forwarded_for,
                               :remote_user,
                               :time,
                               :method,
                               :path_info,
                               :query_string,
                               :http_version,
                               :status,
                               :length,
                               :response_time,
                               :memoizer_size,
                               :memoizer_count,
                               :memoizer_hits,
                               :request_id,
                               :extensions].freeze
          private_constant :SORTED_LOG_FIELDS

          SORTED_ERROR_LOG_FIELDS = [:forwarded_for,
                                     :remote_user,
                                     :time,
                                     :method,
                                     :path_info,
                                     :query_string,
                                     :http_version,
                                     :status,
                                     :error,
                                     :response_time,
                                     :request_id,
                                     :extensions].freeze
          private_constant :SORTED_ERROR_LOG_FIELDS

          private

          def formatted_log(data)
            FORMAT % SORTED_LOG_FIELDS.map { |field| data[field] }
          end

          def formatted_error(data)
            ERROR_FORMAT % SORTED_ERROR_LOG_FIELDS.map { |field| data[field] }
          end
        end
      end
    end
  end
end
