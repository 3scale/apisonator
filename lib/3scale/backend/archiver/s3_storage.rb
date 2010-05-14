module ThreeScale
  module Backend
    module Archiver
      class S3Storage
        include Configurable

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
            options = {}
            options[:access_key_id]     = configuration.aws.access_key_id
            options[:secret_access_key] = configuration.aws.secret_access_key
            options[:use_ssl] = true

            AWS::S3::Base.establish_connection!(options)
          end
        end
      end
    end
  end
end
