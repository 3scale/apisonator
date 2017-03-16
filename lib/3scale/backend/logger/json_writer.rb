module ThreeScale
  module Backend
    class Logger
      class Middleware
        class JsonWriter
          include ThreeScale::Backend::Logger::Middleware::Writer

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
