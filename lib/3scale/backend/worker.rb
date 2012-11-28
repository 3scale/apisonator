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

        @one_off           = options[:one_off]
        @polling_frequency = options[:polling_frequency] || 5

        if configuration.hoptoad.api_key
          Airbrake.configure do |config|
            config.api_key = configuration.hoptoad.api_key
          end
        end

      end

      # == Options
      #
      # - :one_off           - if true, will process one job, then quit
      # - :polling_frequency - when queue is empty, how long to wait (in seconds) before
      #                        polling it for new jobs. If zero, will process everything
      #                        in the queue and quit.
      def self.work(options = {})
				new(options).work
      end

      def work

unless @aggregator_script_sha1


        begin

          code = File.open("lib/3scale/backend/lua/increment_or_set.lua").read
          @aggregator_script_sha1 = redis.script('load',code)
          puts @aggregator_script_sha1

          require "ruby-debug"
        debugger

        rescue Exception => e
          Airbrake.notify(e)
          raise e
        end
end




			  register_worker

        loop do
          break if @shutdown

          if job = reserve
            working_on(job)
            perform(job)
            done_working
          end

          break if one_off?
        end

        unregister_worker
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

      attr_reader :polling_frequency

      private

      def reserve
        queues = QUEUES.map{|q| "queue:#{q}"} # for some reason having this inline in the blpop is invalid syntax in jruby 1.6.0.RC2
        stuff = redis.blpop(*queues, :timeout => 60) # first is queue name, second is our class
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
        redis.del("worker:#{self}")

        stopped!

        Resque::Stat.clear("processed:#{self}")
        Resque::Stat.clear("failed:#{self}")
      end

      def working_on(job)
        data = encode(:queue   => job.queue,
                      :run_at  => Time.now.getutc.to_s,
                      :payload => job.payload)

        redis.set("worker:#{self}", data)
      end

      def done_working
        processed!
        redis.del("worker:#{self}")
      end

      def started!
        redis.set("worker:#{self}:started", Time.now.getutc.to_s)
      end

      def stopped!
        redis.del("worker:#{self}:started")
      end

      def processed!
        Resque::Stat << "processed"
        Resque::Stat << "processed:#{self}"
      end

      def failed!
        Resque::Stat << "failed"
        Resque::Stat << "failed:#{self}"
      end

      def hostname
        @hostname ||= `hostname`.chomp
      end

      def redis
        @redis ||= begin
                     server = (configuration.redis.servers || []).first
                     host, port = server ? server.split(':') : [nil, nil]

                     ::Redis::Namespace.new(
                       :resque,
                       :redis => ::Redis.new(:host => host,
                                             :port => port,
                                             :db   => configuration.redis.db))
                   end
      end
    end
  end
end
