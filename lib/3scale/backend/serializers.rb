module ThreeScale
  module Backend
    module Serializers
      TIME_FORMAT = '%Y-%m-%d %H:%M:%S'

      autoload :StatusV1_0, '3scale/backend/serializers/status_v1.0'
      autoload :StatusV1_1, '3scale/backend/serializers/status_v1.1'
    end
  end
end
