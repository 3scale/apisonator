require_relative '../spec_helper'
require 'timecop'
require 'daemons'
require '3scale/backend/worker_async'

module ThreeScale
  module Backend

    DEFAULT_SERVER = '127.0.0.1:22121'.freeze

    context 'when there are jobs enqueued' do
      let(:provider_key) { 'a_provider_key' }
      let(:service_id) { 'a_service_id' }
      let(:app_id) { 'an_app_id' }
      let(:metric_id) { 'a_metric_id' }
      let(:metric_name) { 'hits' }

      # We are going to enqueue report jobs. And those are enqueued the
      # 'priority' queue.
      let(:queue) { 'priority' }

      let(:current_time) { Time.now }

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

        without_resque_spec do
          Timecop.freeze(current_time) do
            n_reports.times do
              Transactor.report(
                  provider_key,
                  service_id,
                  0 => { app_id: app_id, usage: { metric_name => 1 } }
              )
            end
          end
        end

        worker = Worker.new(async: true, job_fetcher: JobFetcher.new(fetch_timeout: 1))
        worker_thread = Thread.new { worker.work }

        stats_key = Stats::Keys.application_usage_value_key(
            service_id, app_id, metric_id, Period[:day].new(current_time)
        )

        # We do not know when the worker thread will finish processing all the
        # jobs. If it takes too much, we will assume that there has been some
        # kind of error.
        t_start = Time.now

        storage = Redis.new(Storage::Helpers.config_with(
          ThreeScale::Backend.configuration.redis, options: { default_url: "#{DEFAULT_SERVER}" }
        ))
        while storage.get(stats_key).to_i < n_reports
          if Time.now - t_start > 10
            raise 'The worker is taking too much to process the jobs'
          end

          sleep(0.1)
        end

        worker.shutdown

        worker_thread.join

        expect(storage.get(stats_key).to_i).to eq n_reports
      end
    end
  end
end
