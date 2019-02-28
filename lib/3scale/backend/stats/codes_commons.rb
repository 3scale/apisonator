module ThreeScale
  module Backend
    module Stats
      module CodesCommons
        TRACKED_CODES = [200, 404, 403, 500, 503].freeze

        HTTP_CODE_GROUPS_MAP = TRACKED_CODES.each_with_object({}) do |code, hsh|
          hsh[code / 100] = "#{code / 100}XX"
        end

        def self.get_http_code_group(http_code)
          HTTP_CODE_GROUPS_MAP.fetch(http_code / 100)
        end
      end
    end
  end
end
