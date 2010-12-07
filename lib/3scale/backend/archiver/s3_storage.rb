module ThreeScale
  module Backend
    module Archiver
      class S3Storage
        include Configurable

        def initialize(options)
          @bucket_name = options[:bucket] || configuration.archiver.s3_bucket
          establish_connection(options.slice(:access_key_id, :secret_access_key))
        end

        def store(name, content)
          AWS::S3::S3Object.store(name, content, @bucket_name)
        end

        def create_bucket
          AWS::S3::Bucket.create(@bucket_name)
        end

        private

        def establish_connection(options)
          unless AWS::S3::Base.connected?
            options[:use_ssl] = true

            AWS::S3::Base.establish_connection!(options)
          end
        end
      end
    end
  end
end
