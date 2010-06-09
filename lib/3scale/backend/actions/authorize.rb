module ThreeScale
  module Backend
    module Actions
      class Authorize < Action
        def perform(request)
          status = Transactor.authorize(request.params['provider_key'],
                                        request.params['user_key'])
          
          [200, {'Content-Type' => content_type(request)}, [render_status(status, request)]]

        rescue UnsupportedApiVersion
          [406, {}, []]
        rescue Error => exception
          [403, {'Content-Type' => content_type(request)}, [exception.to_xml]]
        end

        private

        def content_type(request)
          case request.api_version
          when '1.0' then 'application/xml'
          else            'application/vnd.3scale-v1.1+xml'
          end
        end

        def render_status(status, request)
          case request.api_version
          when '1.0' then Serializers::StatusV1_0.serialize(status)
          when '1.1' then Serializers::StatusV1_1.serialize(status)
          else raise UnsupportedApiVersion
          end
        end
      end
    end
  end
end
