require 'logger'

module ThreeScale
  module Backend
    # Worker for working off background jobs. This is very stripped down version of the
    # default resque worker with parts of code shamelessly stolen from it. The reason for
    # this stripping is that the resque one does fork before processing each job, and that
    # is too slow.

    class Worker
      include Resque::Helpers
      include Configurable

      # the order is relevant
      QUEUES = [:priority, :main]
      
      def initialize(options = {})
        trap('TERM') { shutdown }
        trap('INT')  { shutdown }

        @one_off = options[:one_off]
        
        ## there is a Logger class in ThreeScale::Backend already and it's for Rack, cannot
        ## reuse it
        @@logger = ::Logger.new(options[:log_file] || configuration.workers_log_file || "/dev/null")
        @@logger.formatter = proc { |severity, datetime, progname, msg|
          "#{severity} #{pid} #{datetime.getutc.strftime("[%d/%b/%Y %H:%M:%S %Z]")} #{msg}\n"
        } 
          
        if configuration.hoptoad.api_key
          Airbrake.configure do |config|
            config.api_key = configuration.hoptoad.api_key
          end
        end
      end
      
      def self.logger()
        @@logger
      end
      
      # == Options
      #
      # - :one_off           - if true, will process one job, then quit
      #
      def self.work(options = {})
				new(options).work
      end
      
      def work
			  register_worker

        ## there is some corner cases in which the job would blow and not go to resque:failed,
        ## for instance if the data contained unprocessable data. For those cases a begin rescue
        ## can be added to the outer loop. Param issues with enconding were solved like this.
        loop do
          break if @shutdown
          
          if job = reserve
            perform(job)
          end

          break if one_off?
        end
       
        unregister_worker
      end
      
      def pid
        @pid ||= Process.pid
      end

      def shutdown
        @shutdown = true
      end

      def to_s
        @to_s ||= "#{hostname}:#{Process.pid}:#{QUEUES.join(',')}"
      end

      def one_off?
        @one_off
      end
         
      private

      def reserve
        @queues ||= QUEUES.map{|q| "queue:#{q}"} 
        stuff = redis.blpop(*@queues, :timeout => 60) # first is queue name, second is our class
        !stuff.nil? && !stuff.empty? && Resque::Job.new(stuff[0], decode(stuff[1]))
      end

      def perform(job)
        job.perform
      rescue Exception => e
        job.fail(e)
        failed!
      end

      def register_worker
        redis.sadd(:workers, self)
        started!
      end

      def unregister_worker
        redis.srem(:workers, self)
        stopped!
      end

      ## the next 4 are required for resque, leave them as is
      def started!
      end
      def stopped!
      end
      def processed!        
      end
      def failed!   
      end
      ## ----

      def hostname
        @hostname ||= `hostname`.chomp
      end

      def redis
        @redis ||= begin
                     ::Redis::Namespace.new(
                       :resque,
                       :redis => Backend::Storage.instance)
                   end
      end
    end
  end
end
