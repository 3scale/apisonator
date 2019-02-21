module ThreeScale
  module Backend
    module Stats
      ##
      # stats/{service:#{service_id}}/response_code:#{response_code}/#{period_granularity}[:#{period_start_time_compacted_to_seconds}]
      #
      class ResponseCodeServiceTypeFactory
        def self.create(job)
          service_keypart = KeyPart.new(:service)
          service_keypart << ServiceKeyPartGenerator.new(job)

          response_code_keypart = KeyPart.new(:response_code)
          response_code_keypart << ResponseCodeKeyPartGenerator.new(job)

          period_keypart = KeyPart.new(:period)
          Commons::PERMANENT_SERVICE_GRANULARITIES.each do |granularity|
            period_keypart << PERIOD_GENERATOR_MAP[granularity].new(job)
          end

          KeyType.new(KeyPartFormatter::ResponseCodeServiceTypeFormatter.new).tap do |key_type|
            key_type << service_keypart
            key_type << response_code_keypart
            key_type << period_keypart
          end
        end
      end

      ##
      # stats/{service:#{service_id}}/cinstance:#{application_id}/response_code:#{response_code}/#{period_granularity}[:#{period_start_time_compacted_to_seconds}]
      #
      class ResponseCodeApplicationTypeFactory
        def self.create(job)
          service_keypart = KeyPart.new(:service)
          service_keypart << ServiceKeyPartGenerator.new(job)

          application_keypart = KeyPart.new(:application)
          application_keypart << AppKeyPartGenerator.new(job)

          response_code_keypart = KeyPart.new(:response_code)
          response_code_keypart << ResponseCodeKeyPartGenerator.new(job)

          period_keypart = KeyPart.new(:period)
          Commons::PERMANENT_EXPANDED_GRANULARITIES.each do |granularity|
            period_keypart << PERIOD_GENERATOR_MAP[granularity].new(job)
          end

          KeyType.new(KeyPartFormatter::ResponseCodeApplicationTypeFormatter.new).tap do |key_type|
            key_type << service_keypart
            key_type << application_keypart
            key_type << response_code_keypart
            key_type << period_keypart
          end
        end
      end

      ##
      # stats/{service:#{service_id}}/uinstance:#{user_id}/response_code:#{response_code}/#{period_granularity}[:#{period_start_time_compacted_to_seconds}]
      #
      class ResponseCodeUserTypeFactory
        def self.create(job)
          service_keypart = KeyPart.new(:service)
          service_keypart << ServiceKeyPartGenerator.new(job)

          user_keypart = KeyPart.new(:user)
          user_keypart << UserKeyPartGenerator.new(job)

          response_code_keypart = KeyPart.new(:response_code)
          response_code_keypart << ResponseCodeKeyPartGenerator.new(job)

          period_keypart = KeyPart.new(:period)
          Commons::PERMANENT_EXPANDED_GRANULARITIES.each do |granularity|
            period_keypart << PERIOD_GENERATOR_MAP[granularity].new(job)
          end

          KeyType.new(KeyPartFormatter::ResponseCodeUserTypeFormatter.new).tap do |key_type|
            key_type << service_keypart
            key_type << user_keypart
            key_type << response_code_keypart
            key_type << period_keypart
          end
        end
      end

      ##
      # stats/{service:#{service_id}}/metric:#{metric_id}/#{period_granularity}[:#{period_start_time_compacted_to_seconds}]
      #
      class UsageServiceTypeFactory
        def self.create(job)
          service_keypart = KeyPart.new(:service)
          service_keypart << ServiceKeyPartGenerator.new(job)

          metric_keypart = KeyPart.new(:metric)
          metric_keypart << MetricKeyPartGenerator.new(job)

          period_keypart = KeyPart.new(:period)
          Commons::PERMANENT_SERVICE_GRANULARITIES.each do |granularity|
            period_keypart << PERIOD_GENERATOR_MAP[granularity].new(job)
          end

          KeyType.new(KeyPartFormatter::UsageServiceTypeFormatter.new).tap do |key_type|
            key_type << service_keypart
            key_type << metric_keypart
            key_type << period_keypart
          end
        end
      end

      ##
      # stats/{service:#{service_id}}/cinstance:#{application_id}/metric:#{metric_id}/#{period_granularity}[:#{period_start_time_compacted_to_seconds}]
      #
      class UsageApplicationTypeFactory
        def self.create(job)
          service_keypart = KeyPart.new(:service)
          service_keypart << ServiceKeyPartGenerator.new(job)

          metric_keypart = KeyPart.new(:metric)
          metric_keypart << MetricKeyPartGenerator.new(job)

          application_keypart = KeyPart.new(:application)
          application_keypart << AppKeyPartGenerator.new(job)

          period_keypart = KeyPart.new(:period)
          Commons::PERMANENT_EXPANDED_GRANULARITIES.each do |granularity|
            period_keypart << PERIOD_GENERATOR_MAP[granularity].new(job)
          end

          KeyType.new(KeyPartFormatter::UsageApplicationTypeFormatter.new).tap do |key_type|
            key_type << service_keypart
            key_type << metric_keypart
            key_type << application_keypart
            key_type << period_keypart
          end
        end
      end

      ##
      # stats/{service:#{service_id}}/uinstance:#{user_id}/metric:#{metric_id}/#{period_granularity}[:#{period_start_time_compacted_to_seconds}]
      #
      class UsageUserTypeFactory
        def self.create(job)
          service_keypart = KeyPart.new(:service)
          service_keypart << ServiceKeyPartGenerator.new(job)

          metric_keypart = KeyPart.new(:metric)
          metric_keypart << MetricKeyPartGenerator.new(job)

          user_keypart = KeyPart.new(:user)
          user_keypart << UserKeyPartGenerator.new(job)

          period_keypart = KeyPart.new(:period)
          Commons::PERMANENT_EXPANDED_GRANULARITIES.each do |granularity|
            period_keypart << PERIOD_GENERATOR_MAP[granularity].new(job)
          end

          KeyType.new(KeyPartFormatter::UsageUserTypeFormatter.new).tap do |key_type|
            key_type << service_keypart
            key_type << metric_keypart
            key_type << user_keypart
            key_type << period_keypart
          end
        end
      end

      class KeyTypesFactory
        def self.create(job)
          [].tap do |keys|
            # Response code class types
            keys << ResponseCodeServiceTypeFactory.create(job)
            keys << ResponseCodeApplicationTypeFactory.create(job)
            keys << ResponseCodeUserTypeFactory.create(job)

            # Usage class types
            keys << UsageServiceTypeFactory.create(job)
            keys << UsageApplicationTypeFactory.create(job)
            keys << UsageUserTypeFactory.create(job)
          end
        end
      end
    end
  end
end