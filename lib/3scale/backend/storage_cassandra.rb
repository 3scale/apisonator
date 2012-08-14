module ThreeScale
  module Backend
    class StorageCassandra < ::CassandraCQL::Database
      include Configurable
      include Backend::Aggregator::StatsBatcher

      DEFAULT_SERVER = '127.0.0.1:9160'
      DEFAULT_KEYSPACE = 'backend_testing'
      
      ## WARNING: for the execute_cql_query (insterting batch) we do not want any timeout. If happens, we are 
      ## quite screwed, since it will raise exception but the data will have been processed by cassandra.
      ## retries makes it worse since we will be overcouinting x retries times more. 
      THRIFT_OPTIONS = {:retries => 2, :timeout => 60, :timeout_overrides => {:execute_cql_query => 0}}
        

      def initialize(options)

        @latest_time_bucket = nil
        @latest_batch_str = nil
        @latest_digest = nil

        init_servers = options[:servers] || Array(DEFAULT_SERVER)
        init_keyspace = options[:keyspace] || DEFAULT_KEYSPACE
        
        super(init_servers,{:keyspace => init_keyspace}, THRIFT_OPTIONS)
      
        self.connection.add_callback(:on_exception) do |exception, method|
          if method.to_sym==:execute_cql_query && exception.message.match(/Socket: Timed out reading/)
            ## this should not happen, if so, we need to know
            enc = Yajl::Encoder.encode(latest_batch_saved_info)
            Storage.instance.rpush("stats:timed_out",enc)
          end
        end
          
      end
      

      # Returns a shared instance of the storage. If there is no instance yet,
      # creates one first. If you want to always create a fresh instance, set the
      # +reset+ parameter to true.
      def self.instance(reset = false)
       
        @@instance = nil if reset
        @@instance ||= new(:keyspace => configuration.cassandra.keyspace,
                           :servers  => configuration.cassandra.servers)
                            
        @@instance      
      end
      
      def self.reset_to_nil!
        @@instance = nil
      end
      
      def clear_keyspace!
        schema.column_family_names.each do |cf|
          execute_cql_query("truncate #{cf}")
        end
      end
      
      ## returns an array of repeated batches!! this better be always empty. Otherwise we are overcounting
      
      def repeated_batches
        
        res = Array.new
        
        r = execute("SELECT * FROM StatsChecker;")
        r.fetch do |row|
          row.to_hash.each do |k, v|
            res << k if k!="KEY" && v.is_a?(Fixnum) && v>1
          end
        end
        
        res
      end
      
      def latest_batch_saved_info
        return [@latest_time_bucket, @latest_digest, @latest_batch_str]
      end
      
      def time_bucket_already_inserted?(bucket)
        pre = bucket.to_i - 1
        post = bucket.to_i + 1

        sentence = "SELECT '#{pre}'..'#{post}' FROM StatsChecker WHERE key='day-#{bucket[0..7]}';"

        r = execute(sentence)
        r.fetch do |row|
          h = row.to_hash
          h.each do |k, v|
            return true if k!="key" && k.split("-")[0]==bucket && v>0  
          end

        end
        return false
      end
      
      def undo_execute_batch(batch_str)
        
        ## FIXME
        ## This assumes that the format of an UPDATE leaves a space before and after the increment value.
        ## This is the case of CQL sentences build with StorageCassandra.add2cql. There are test to check if 
        ## the format changes, but be careful. Needs to be refactored to be more robust.
         
        complementary = batch_str.gsub(" + "," - ")
        execute_cql_query(complementary)
        
      end
      
      ## execute batch should replace all execute_cql_query related to batched
      def execute_batch(time_bucket, batch_str)

        digest = Digest::MD5.hexdigest(batch_str)
        
        str = "BEGIN BATCH " << batch_str
        
        col_key = "#{time_bucket}-#{digest}"
        row_key = "day-#{time_bucket[0..7]}"
        
        control_counter = StorageCassandra.add2cql(:StatsChecker,row_key,1,col_key)
        
        str << " " << control_counter 
        str << " APPLY BATCH;"
        
        @latest_time_bucket = time_bucket
        @latest_digest = digest
        @latest_batch_str = str
        
        ## let's save the batch on disk
        root_directory = "#{configuration.cassandra_archiver.path}/#{row_key}/"
        FileUtils.mkdir_p(root_directory)
        filename = col_key
        
        ## this a single line it's empty if not immediately read, probably not flushed yet. Force it with close.
        f = File.open("#{root_directory}#{filename}","w")
        f.write(str)
        f.close
        
        ## let's save the batch on cassandra
              
        execute_cql_query(str)
        
      end
      
      
      def add(column_family, row_key, value, col_key)
        execute_cql_query(StorageCassandra.add2cql(column_family, row_key, value, col_key))
      end
      
      def get(column_family, row_key, col_key)
        r = execute(StorageCassandra.get2cql(column_family, row_key, col_key))
        r.fetch do |row|
          return row.to_hash[col_key]
        end 
        return nil
      end
      
      
      def self.get2cql(column_family, row_key, col_key)
        str = "SELECT '" << col_key << "'"
        str << " FROM '" << column_family.to_s << "'"
        str << " WHERE key='" + row_key + "';"
      end
      
      def self.add2cql(column_family, row_key, value, col_key)
        if value.is_a?(Array) || col_key.is_a?(Array)
          if value.size!=col_key.size || value.is_a?(Array)!=col_key.is_a?(Array) || value.size==0
            raise Exception, "error on parameters of add2cql, value: #{value.inspect}, col_key: #{col_key.inspect}"
          end
          str = "UPDATE " << column_family.to_s << " SET "
          col_key.each_with_index do |ck, i|
            str << ", " if i>0 
            str << "'" << ck << "'='" << ck << "' + " << value[i].to_s
          end
          str << " WHERE key='" << row_key << "';"
        else
          StorageCassandra.add2cql_single(column_family, row_key, value, col_key)
        end
      end
      
      def self.add2cql_single(column_family, row_key, value, col_key)
        str = "UPDATE " << column_family.to_s
        str << " SET '" << col_key << "'='" << col_key << "' + " << value.to_s
        str << " WHERE key='" << row_key << "';"
      end  
        
    end
  end
end
