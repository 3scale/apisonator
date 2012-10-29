require '3scale/backend/archiver/s3_storage'

module ThreeScale
  module Backend
    module Archiver
      extend self
      include Configurable

      # Add the transactions to the archive.
      def add_all(transactions)
        transactions.each { |transaction| add(transaction) }
      end

      # Collects all completed temporary files and sends them to a remote storage.
      #
      # == Options
      #
      # +storage+:: what storage to use. Default is S3Storage which stores the data on Amazon's S3
      # +tag+::     some string that will be appended to the name of the file on the remote
      #             storage. This is useful if there are multiple machines using the same storage,
      #             so each machine can use an unique tag (it's hostname for example).
      #
      def store(options = {})
        raise ArgumentError ':tag is missing' unless options[:tag]

        storage = options[:storage] || S3Storage.new(configuration.archiver.s3_bucket)
        tag     = options[:tag]

        each_file_to_store do |file|
          service_id, date = extract_service_id_and_date(file)

          File.open(file, 'r') do |source_io|
            content = complete_and_compress(source_io, service_id)
            storage.store(name_for_storage(service_id, date, tag), content)
          end
        end
      end

      def cleanup
        each_file_to_cleanup do |file|
          File.delete(file)
        end

        Dir["#{root}/*"].each do |dir|
          Dir.delete(dir) if File.directory?(dir) && Dir["#{dir}/**/*"].empty?
        end
      end

      private

      def add(transaction)
        path = path_for(transaction)
        ensure_directory_exists(File.dirname(path))

        File.open(path, 'a') do |io|
          serialize(io, transaction)
        end
      end

      def path_for(transaction)
        date = transaction[:timestamp].strftime('%Y%m%d')

        "#{root}/service-#{transaction[:service_id]}/#{date}.xml.part"
      end

      def root
        configuration.archiver.path
      end

      def ensure_directory_exists(dir)
        FileUtils.mkdir_p(dir)
      end

      def serialize(io, transaction)
        builder = Builder::XmlMarkup.new(:target => io)
        builder.transaction do

          builder.application_id transaction[:application_id]
          builder.timestamp      transaction[:timestamp].strftime('%Y-%m-%d %H:%M:%S')
          builder.ip             transaction[:client_ip] if transaction[:client_ip]

          builder.values do
            transaction[:usage].each do |metric_id, value|
              builder.value value, 'metric_id' => metric_id
            end
          end
        end
      end

      def each_file_to_store(&block)
        each_partial_file_older_than(Time.now.getutc.beginning_of_day_hack, &block)
      end

      def each_file_to_cleanup(&block)
        each_partial_file_older_than((Time.now.getutc - Time::ONE_DAY).beginning_of_day_hack, &block)
      end

      def each_partial_file_older_than(time)
        Dir["#{root}/**/*.xml.part"].each do |file|
          file_time = Time.parse_to_utc(file[/([^\/\.]+)\.xml\.part$/, 1])

          yield(file) if file_time < time
        end
      end

      def extract_service_id_and_date(file)
        file =~ /service\-([^\/\.]+)\/([^\/\.]+)\.xml\.part$/
        [$1, $2]
      end

      def name_for_storage(service_id, date, tag)
        "service-#{service_id}/#{date}/#{tag}.xml.gz"
      end

      CHUNK_SIZE = 1024

      def complete_and_compress(source_io, service_id)
        buffer  = ''
        gzip_io = Zlib::GzipWriter.new(StringIO.new(buffer))

        builder = Builder::XmlMarkup.new(:target => gzip_io)
        builder.instruct!

        builder.transactions(:service_id => service_id) do
          while chunk = source_io.read(CHUNK_SIZE)
            gzip_io.write(chunk)
          end
        end

        buffer
      ensure
        gzip_io.close rescue nil
      end
    end
  end
end
