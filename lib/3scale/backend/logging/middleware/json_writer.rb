require '3scale/backend/logging/middleware/writer'

module ThreeScale
  module Backend
    module Logging
      class Middleware
        class JsonWriter
          include Middleware::Writer

          private

          def formatted_log(data)
            data.to_json + "\n".freeze
          end

          alias_method :formatted_error, :formatted_log
        end
      end
    end
  end
end
