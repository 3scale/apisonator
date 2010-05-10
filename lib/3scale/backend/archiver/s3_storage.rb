module ThreeScale
  module Backend
    class Archiver
      class S3Storage
        def initialize(bucket_name)
          @bucket_name = bucket_name
          establish_connection
        end

        def store(name, content)
          AWS::S3::S3Object.store(name, content, @bucket_name)
        end

        def create_bucket
          AWS::S3::Bucket.create(@bucket_name)
        end

        private

        def establish_connection
          unless AWS::S3::Base.connected?
            options = ThreeScale::Backend.configuration.aws

            # symbolize keys
            options = options.inject({}) do |memo, (key, value)|
              memo.update(key.to_sym => value)
            end

            options[:use_ssl] = true

            AWS::S3::Base.establish_connection!(options)
          end
        end
      end
    end
  end
end
