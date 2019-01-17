module ThreeScale
  module Backend
    module Stats
      class DeleteJobDef
        ATTRIBUTES = %i[service_id applications metrics users from to context_info].freeze
        private_constant :ATTRIBUTES
        attr_accessor(*ATTRIBUTES)

        def self.attribute_names
          ATTRIBUTES
        end

        def initialize(params = {})
          self.class.attribute_names.each do |key|
            send("#{key}=", params[key]) unless params[key].nil?
          end
        end

        def run_async
          validate
          Resque.enqueue(PartitionGeneratorJob, Time.now.getutc.to_f, service_id, applications,
                         metrics, users, from, to, context_info)
        end

        def to_json
          to_hash.to_json
        end

        def to_hash
          Hash[self.class.const_get(:ATTRIBUTES).collect { |key| [key, send(key)] }]
        end

        def validate
          # from and to valid epoch times
          unless from.is_a? Integer
            raise DeleteServiceStatsValidationError.new(service_id, 'from field validation error')
          end

          unless to.is_a? Integer
            raise DeleteServiceStatsValidationError.new(service_id, 'to field validation error')
          end

          if Time.at(to) < Time.at(from)
            raise DeleteServiceStatsValidationError.new(service_id, 'from < to fields validation error')
          end

          # application is array
          unless applications.is_a? Array
            raise DeleteServiceStatsValidationError.new(service_id, 'applications field validation error')
          end

          if applications.size > 0
            unless applications.all? { |x| x.is_a? String }
              raise DeleteServiceStatsValidationError.new(service_id, 'applications values validation error')
            end
          end

          # metrics is array
          unless metrics.is_a? Array
            raise DeleteServiceStatsValidationError.new(service_id, 'metrics field validation error')
          end

          if metrics.size > 0
            unless metrics.all? { |x| x.is_a? String }
              raise DeleteServiceStatsValidationError.new(service_id, 'metrics values validation error')
            end
          end

          # users is array
          unless (users.is_a? Array)
            raise DeleteServiceStatsValidationError.new(service_id, 'users field validation error')
          end

          if users.size > 0
            unless users.all? { |x| x.is_a? String }
              raise DeleteServiceStatsValidationError.new(service_id, 'users values validation error')
            end
          end
        end
      end
    end
  end
end
