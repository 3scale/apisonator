module ThreeScale
  module Backend
    module Stats
      class DeleteJobDef
        ATTRIBUTES = %i[service_id applications metrics from to context_info].freeze
        private_constant :ATTRIBUTES
        attr_reader(*ATTRIBUTES)

        def self.attribute_names
          ATTRIBUTES
        end

        def initialize(params = {})
          ATTRIBUTES.each do |key|
            instance_variable_set("@#{key}".to_sym, params[key]) unless params[key].nil?
          end
          validate
        end

        def run_async
          Resque.enqueue(PartitionGeneratorJob, Time.now.getutc.to_f, service_id, applications,
                         metrics, from, to, context_info)
        end

        def to_json
          to_hash.to_json
        end

        def to_hash
          Hash[ATTRIBUTES.collect { |key| [key, send(key)] }]
        end

        private

        def validate
          # from and to valid epoch times
          raise_validation_error('from field not integer') unless from.is_a? Integer
          raise_validation_error('from field is zero') if from.zero?
          raise_validation_error('to field not integer') unless to.is_a? Integer
          raise_validation_error('to field is zero') if to.zero?
          raise_validation_error('from < to fields') if Time.at(to) < Time.at(from)
          # application is array
          raise_validation_error('applications field') unless applications.is_a? Array
          raise_validation_error('applications values') unless applications.all? do |x|
            x.is_a?(String) || x.is_a?(Integer)
          end
          # metrics is array
          raise_validation_error('metrics field') unless metrics.is_a? Array
          raise_validation_error('metrics values') unless metrics.all? do |x|
            x.is_a?(String) || x.is_a?(Integer)
          end
        end

        def raise_validation_error(msg)
          raise DeleteServiceStatsValidationError.new(service_id, msg)
        end
      end
    end
  end
end
