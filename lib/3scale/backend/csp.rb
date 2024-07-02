require '3scale/backend/headers/stringify'

# CSP support
#
# Please see references:
#
#     https://content-security-policy.com/
#     https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
#     https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy
#     https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/Sources
module ThreeScale
  module Backend
    module CSP
      extend Headers::Stringify

      CSP_VALUES = "default-src 'self'".freeze
      private_constant :CSP_VALUES

      CSP_HEADERS = {
        'Content-Security-Policy'.freeze => CSP_VALUES
      }.freeze
      private_constant :CSP_HEADERS

      stringify_consts :CSP_VALUES, :CSP_HEADERS

      def self.headers
        CSP_HEADERS
      end
    end
  end
end
