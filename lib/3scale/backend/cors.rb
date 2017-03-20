# CORS support
#
# Please see references:
#
# https://www.w3.org/TR/cors/
# https://code.google.com/archive/p/html5security/wikis/CrossOriginRequestSecurity.wiki
#
module ThreeScale
  module Backend
    module CORS
      def self.stringify_consts(*consts)
        consts.each do |k|
          val = const_get k
          val = val.respond_to?(:join) ? val.join(', ') : val.to_s
          k_s = "#{k}_S".to_sym
          const_set(k_s, val.freeze)
          private_constant k_s
        end
      end
      private_class_method :stringify_consts

      MAX_AGE = 86400
      private_constant :MAX_AGE

      ALLOW_ORIGIN = '*'.freeze
      private_constant :ALLOW_ORIGIN

      ALLOW_METHODS = [
        'GET'.freeze,
        'POST'.freeze,
        'PATCH'.freeze,
        'PUT'.freeze,
        'DELETE'.freeze
      ].freeze
      private_constant :ALLOW_METHODS

      ALLOW_HEADERS = [
        'Authorization'.freeze,
        'Accept-Encoding'.freeze,
        'Content-Type'.freeze,
        'Cache-Control'.freeze,
        'Accept'.freeze,
        'If-Match'.freeze,
        'If-Modified-Since'.freeze,
        'If-None-Match'.freeze,
        'If-Unmodified-Since'.freeze,
        'X-Requested-With'.freeze,
        'X-HTTP-Method-Override'.freeze,
        '3scale-options'.freeze,
      ].freeze
      private_constant :ALLOW_HEADERS

      EXPOSE_HEADERS = [
        'ETag'.freeze,
        'Link'.freeze,
        '3scale-rejection-reason'.freeze,
      ].freeze
      private_constant :EXPOSE_HEADERS

      stringify_consts :MAX_AGE, :ALLOW_METHODS, :ALLOW_HEADERS, :EXPOSE_HEADERS

      HEADERS = {
        'Access-Control-Allow-Origin'.freeze => ALLOW_ORIGIN,
        'Access-Control-Expose-Headers'.freeze => EXPOSE_HEADERS_S,
      }.freeze
      private_constant :HEADERS

      OPTIONS_HEADERS = {
        'Access-Control-Max-Age'.freeze => MAX_AGE_S,
        'Access-Control-Allow-Methods'.freeze => ALLOW_METHODS_S,
        'Access-Control-Allow-Headers'.freeze => ALLOW_HEADERS_S,
      }.merge(HEADERS).freeze
      private_constant :OPTIONS_HEADERS

      def self.headers
        HEADERS
      end

      def self.options_headers
        OPTIONS_HEADERS
      end
    end
  end
end
