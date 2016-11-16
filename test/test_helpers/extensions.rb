module TestHelpers
  module Extensions
    def self.included(base)
      base.const_set(:Extensions, ExtensionConstants)
      base.extend(ClassMethods)
    end

    module ExtensionConstants
      NO_BODY = URI.encode('no_body=1').freeze
      REJECTION_REASON_HEADER = URI.encode('rejection_reason_header=1').freeze
      HIERARCHY = URI.encode('hierarchy=1').freeze
    end

    module ClassMethods
      # this is exercising all the no_body variants
      #
      # Block returns two values:
      # 1st: parameters hash to the path endpoint - required
      # 2nd: Rack's environment - optional
      def test_nobody(rack_method, path, &blk)
        test "call to #{rack_method.upcase} #{path} with no_body option responds 200" do
          # The below 3 lines are repeated in each example. DRYing them up
          # involves some metaprogramming magic. Not worth it just for these.
          params, env = instance_exec(&blk)
          params ||= {}
          env ||= {}

          send(rack_method, path, params, env.merge({
            'HTTP_3SCALE_OPTIONS' => ExtensionConstants::NO_BODY
          }))

          assert_equal 200, last_response.status
          assert_equal '', last_response.body
        end

        test "call to #{rack_method.upcase} #{path} with deprecated no_body=1 responds 200" do
          params, env = instance_exec(&blk)
          params ||= {}
          env ||= {}

          send(rack_method, path, params.merge({ no_body: 1 }))

          assert_equal 200, last_response.status
          assert_equal '', last_response.body
        end

        test "call to #{rack_method.upcase} #{path} with deprecated no_body=true responds 200" do
          params, env = instance_exec(&blk)
          params ||= {}
          env ||= {}

          send(rack_method, path, params.merge({ no_body: true }))

          assert_equal 200, last_response.status
          assert_equal '', last_response.body
        end
      end
    end
  end
end
