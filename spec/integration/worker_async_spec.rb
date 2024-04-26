require 'timecop'
require 'daemons'
require '3scale/backend/worker_async'

module ThreeScale
  module Backend

    DEFAULT_SERVER = '127.0.0.1:6379'.freeze

    context 'when there are jobs enqueued', if: configuration.redis.async do
      let(:job_fetcher) { JobFetcher.new(fetch_timeout: 1) }

      subject { Worker.new(async: true, job_fetcher: job_fetcher) }

      let(:storage) { Service.storage }
      let(:resque_redis ) { job_fetcher.instance_variable_get(:@redis) }

      let(:provider_key) { 'a_provider_key' }
      let(:service_id) { 'a_service_id' }
      let(:app_id) { 'an_app_id' }
      let(:metric_id) { 'a_metric_id' }
      let(:metric_name) { 'hits' }

      let(:current_time) { Time.now }

      let(:job_adder) do
        proc do
          Transactor.report(
            provider_key,
            service_id,
            0 => { app_id: app_id, usage: { metric_name => 1 } }
          )
        end
      end

      let(:multi_job_adder) do
        proc do |num|
          raise unless num >= 5

          num.times { job_adder.call }

          # add some jobs to all queues
          %w[queue:main queue:stats].each do |queue|
            2.times do
              moved = resque_redis.brpoplpush("queue:priority", queue, 5)
              expect(moved).to be_truthy
              expect(moved).not_to be_empty
            end
          end
        end
      end

      let(:report_waiter) do
        proc do |stats_key, num_reports|
          t_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          while storage.get(stats_key).to_i < num_reports
            if Process.clock_gettime(Process::CLOCK_MONOTONIC) - t_start > 2
              raise 'The worker is taking too much to process the jobs'
            end

            sleep(0.01)
          end
        end
      end

      before do
        Service.save!(provider_key: provider_key, id: service_id)

        Application.save(service_id: service_id,
                         id: app_id,
                         state: :active)

        Metric.save(service_id: service_id,
                    id: metric_id,
                    name: metric_name)
      end

      it 'processes them' do
        # For this test, we are going to perform a number of reports, and then,
        # verify that the stats usage keys have been updated correctly.

        n_reports = 10
        stats_key = Stats::Keys.application_usage_value_key(
          service_id, app_id, metric_id, Period[:day].new(current_time)
        )
        work_task = nil

        Timecop.freeze(current_time) do
          without_resque_spec do
            multi_job_adder.call(n_reports) # add jobs before worker started
          end

          work_task = Async { subject.work }

          report_waiter.call(stats_key, n_reports)

          without_resque_spec { 5.times { job_adder.call } } # add jobs after worker started and finished previous
          report_waiter.call(stats_key, n_reports + 5)
        end

        subject.shutdown
        work_task&.wait

        expect(storage.get(stats_key).to_i).to eq(n_reports + 5)
      rescue StandardError => e
        subject.shutdown
        work_task&.wait
        RSpec::Expectations.fail_with(e.message)
      end
    end
  end
end
