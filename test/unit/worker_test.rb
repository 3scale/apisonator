require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class WorkerTest < Test::Unit::TestCase
  include TestHelpers::Fixtures

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_provider_fixtures

    @application_one = Application.save(:service_id => @service_id,
                                        :id         => next_id,
                                        :state      => :active,
                                        :plan_id    => @plan_id,
                                        :plan_name  => @plan_name)

    @application_two = Application.save(:service_id => @service_id,
                                        :id         => next_id,
                                        :state      => :active,
                                        :plan_id    => @plan_id,
                                        :plan_name  => @plan_name)

    @metric_id = next_id
    Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')
  end

  def test_format_of_a_job
    encoded_job = Yajl::Encoder.encode(:class => 'TestJob', :args => [{'0'=> {:app_id => "app_id with spaces"}}])
    assert_equal '{"class":"TestJob","args":[{"0":{"app_id":"app_id with spaces"}}]}', encoded_job
  end

  def test_no_jobs_in_the_queue
    # Stub blpop to avoid waiting until timeout.
    Redis.any_instance.stubs(:blpop).returns(nil)
    TestHelpers::Storage.client_class.any_instance.stubs(:blpop).returns(nil)

    Worker.work(:one_off => true)
  end

  def test_logging_works
    Timecop.freeze(Time.utc(2011, 12, 12, 11, 48)) do
      log_file = "/tmp/temp_3scale_backend_worker.log"
      FileUtils.remove_file(log_file, :force => true)

      ## creates the log file when on new
      Backend::Worker.new(:one_off => true, :log_file => log_file)
      line = File.new(log_file,"r").read
      assert_equal "# Logfile created on 2011-12-12 11:48:00 UTC by logger.rb", line.split("/").first

      ## creates the log file when on work
      FileUtils.remove_file(log_file, :force => true)
      job_fetcher = ThreeScale::Backend::JobFetcher.new(fetch_timeout: 1)
      worker = Backend::Worker.new(:one_off => true, :log_file => log_file, job_fetcher:)

      # Create a mock job to be returned by the fetcher
      job = ::Resque::Job.new(:priority,
                               'class' => 'ThreeScale::Backend::Transactor::ReportJob',
                               'args' => [@service_id,
                                          {'0' => {'app_id' => @application_one.id, 'usage' => {'hits' => 1}},
                                           '1' => {'app_id' => @application_two.id, 'usage' => {'hits' => 1}}},
                                          Time.utc(2011, 12, 12, 11, 48).to_f,
                                          {}])
      job_fetcher.stubs(:fetch).returns(job)

      worker.work

      log_contents = File.read(log_file)
      assert_match /Logfile created on 2011-12-12 11:48:00 UTC by logger.rb/, log_contents # Header
      assert_match /ReportJob/, log_contents  # Processed job

      FileUtils.remove_file(log_file, :force => true)
    end
  end

  # TODO: more tests here.
end
