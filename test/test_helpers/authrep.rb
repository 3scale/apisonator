module TestHelpers
  module AuthRep
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      AUTHREP_ENDPOINTS = { authrep: '/transactions/authrep.xml',
                            oauth_authrep: '/transactions/oauth_authrep.xml' }
      private_constant :AUTHREP_ENDPOINTS

      private

      def test_authrep(title, on: AUTHREP_ENDPOINTS.keys, except: [], &blk)
        authrep_endpoints(on: on, except: except).each do |m, url|
          test "#{m} #{title}" do
            begin
              instance_exec url, m, &blk
            rescue => e
              # remove noise from backtrace
              e.backtrace.reject! { |b| b =~ Regexp.new("\\A#{Regexp.escape __FILE__}\\:") }
              raise e
            end
          end
        end
      end

      # generates the different authrep endpoints in case direct test generation
      # is not desired (ie. when combining with test generators).
      def authrep_endpoints(on: AUTHREP_ENDPOINTS.keys, except: [])
        endpoints = Array(on) - Array(except)
        AUTHREP_ENDPOINTS.lazy.select { |m, _| endpoints.include? m }
      end
    end
  end
end
