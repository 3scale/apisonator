module TestHelpers
  module Extensions
    def self.included(base)
      base.const_set(:Extensions, ExtensionConstants)
      base.extend(ClassMethods)
    end

    module ExtensionConstants
      NO_BODY = URI.encode_www_form(no_body: 1).freeze
      REJECTION_REASON_HEADER = URI.encode_www_form(rejection_reason_header: 1).freeze
      HIERARCHY = URI.encode_www_form(hierarchy: 1).freeze
      LIMIT_HEADERS = URI.encode_www_form(limit_headers: 1).freeze
      FLAT_USAGE = URI.encode_www_form(flat_usage: 1).freeze
      LIST_APP_KEYS = URI.encode_www_form(list_app_keys: 1).freeze
    end

    module ClassMethods
      # this is exercising all the no_body variants
      #
      # Block returns two values:
      # 1st: parameters hash to the path endpoint - required
      # 2nd: Rack's environment - optional
      def test_nobody(rack_method, path, &blk)
        test "call to #{rack_method.upcase} #{path} without no_body responds with a body" do
          # The below 3 lines are repeated in each example. DRYing them up
          # involves some metaprogramming magic. Not worth it just for these.
          params, env = instance_exec(&blk)
          params ||= {}
          env ||= {}

          send(rack_method, path, params, env)

          # _some_ body has to be generated
          assert_not_equal '', last_response.body
        end

        test "call to #{rack_method.upcase} #{path} with no_body option responds without body" do
          params, env = instance_exec(&blk)
          params ||= {}
          env ||= {}

          send(rack_method, path, params, env.merge({
            'HTTP_3SCALE_OPTIONS' => ExtensionConstants::NO_BODY
          }))

          assert_equal '', last_response.body
        end

        test "call to #{rack_method.upcase} #{path} with deprecated no_body=1 responds without body" do
          params, env = instance_exec(&blk)
          params ||= {}
          env ||= {}

          send(rack_method, path, params.merge({ no_body: 1 }))

          assert_equal '', last_response.body
        end

        test "call to #{rack_method.upcase} #{path} with deprecated no_body=true responds without body" do
          params, env = instance_exec(&blk)
          params ||= {}
          env ||= {}

          send(rack_method, path, params.merge({ no_body: true }))

          assert_equal '', last_response.body
        end

        test "call to #{rack_method.upcase} #{path} with deprecated no_body=0 responds with body" do
          params, env = instance_exec(&blk)
          params ||= {}
          env ||= {}

          send(rack_method, path, params.merge({ no_body: 0 }))

          assert_not_equal '', last_response.body
        end

        test "call to #{rack_method.upcase} #{path} with deprecated no_body=false responds with body" do
          params, env = instance_exec(&blk)
          params ||= {}
          env ||= {}

          send(rack_method, path, params.merge({ no_body: false }))

          assert_not_equal '', last_response.body
        end
      end
    end
  end
end
