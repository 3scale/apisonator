require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class WorkerTest < Test::Unit::TestCase
  def setup
  end

  def test_queue_name
    assert_equal :priority, Worker::QUEUES[0]
    assert_equal :main, Worker::QUEUES[1]
  end

  def test_pops_jobs_from_a_queue
    encoded_job = Yajl::Encoder.encode(:class => 'TestJob', :args => [])

    redis = Redis.any_instance
    redis.expects(:blpop).with(*Worker::QUEUES.map{|q| "resque:queue:#{q}"}, "60").returns(encoded_job)

    Worker.work(:one_off => true)
  end

  def test_no_jobs_in_the_queue
    redis = Redis.any_instance
    redis.expects(:blpop).with(*Worker::QUEUES.map{|q| "resque:queue:#{q}"}, "60").returns(nil)

    Worker.work(:one_off => true)
  end

  # TODO: more tests here.
end
