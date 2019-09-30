require '3scale/backend/job_fetcher'

module ThreeScale
  module Backend
    class WorkerSync
      include Backend::Worker

      def initialize(options = {})
        trap('TERM') { shutdown }
        trap('INT')  { shutdown }

        @one_off = options[:one_off]
        @job_fetcher = options[:job_fetcher] || JobFetcher.new
      end

      def work
        register_worker

        loop do
          break if @shutdown

          job = @job_fetcher.fetch
          perform(job) if job

          break if one_off?
        end

        unregister_worker
      end
    end
  end
end
