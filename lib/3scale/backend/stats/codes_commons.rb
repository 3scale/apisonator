module ThreeScale
  module Backend
    module Stats
      module CodesCommons
        TRACKED_CODES = [200, 404, 403, 500, 503].freeze
        TRACKED_CODE_GROUPS = ['2XX'.freeze, '4XX'.freeze, '5XX'.freeze].freeze

        def self.get_http_code_group(http_code)
          "#{http_code / 100}XX"
        end
      end
    end
  end
end
