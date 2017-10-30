module TestHelpers
  module HTTP
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      VALID_CTYPES = ['application/x-www-form-urlencoded', 'multipart/form-data', '', nil].freeze
      INVALID_CTYPES = ['text/plain', 'image/invalid', 'some_content_type', 'application/xml+invalid'].freeze
      private_constant :VALID_CTYPES, :INVALID_CTYPES

      private

      def test_post(endpoint, params = {}, ctypes: VALID_CTYPES, invalid_ctypes: INVALID_CTYPES)
        valid_ctypes = Array(ctypes)
        (Array(invalid_ctypes) - valid_ctypes).each do |ctype|
          test "POST to #{endpoint} returns invalid content type error with #{ctype.inspect}" do
            post endpoint, params, 'CONTENT_TYPE' => ctype
            error = Nokogiri::XML(last_response.body).at('error:root')
            assert_not_nil error
            assert_equal 'content_type_invalid', error['code']
            assert_equal "invalid Content-Type: #{ctype}", error.content
            assert_equal 400, last_response.status
          end
        end

        valid_ctypes.each do |ctype|
          test "POST to #{endpoint} does not produce invalid content type error with #{ctype.inspect}" do
            post endpoint, params, 'CONTENT_TYPE' => ctype
            error = Nokogiri::XML(last_response.body).at('error:root')
            if error
              assert_not_equal 'content_type_invalid', error['code']
              assert_not_equal "invalid Content-Type: #{ctype}", error.content
            end
          end

          if ctype && !ctype.empty?
            test "POST to #{endpoint} does not produce invalid content type error with #{ctype.inspect} and a parameter (charset=UTF-8)" do
              post endpoint, params, 'CONTENT_TYPE' => "#{ctype}; charset=UTF-8"
              error = Nokogiri::XML(last_response.body).at('error:root')
              if error
                assert_not_equal 'content_type_invalid', error['code']
                assert !error.content.start_with?("invalid Content-Type: #{ctype}")
              end
            end
          end
        end

        string_ctypes = valid_ctypes.select { |c| c && !c.empty? }
        if !string_ctypes.empty?
          upcased_ctype = string_ctypes.sample.upcase
          test "POST to #{endpoint} does not produce invalid content type error with upcased content type #{upcased_ctype}" do
            post endpoint, params, 'CONTENT_TYPE' => "#{upcased_ctype}; charset=UTF-8"
            error = Nokogiri::XML(last_response.body).at('error:root')
            if error
              assert_not_equal 'content_type_invalid', error['code']
              assert !error.content.start_with?("invalid Content-Type: #{upcased_ctype}")
            end
          end
        end
      end
    end
  end
end
