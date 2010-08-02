require File.dirname(__FILE__) + '/../test_helper'

class WorkerTest < Test::Unit::TestCase
  def setup
  end

  def test_queue_name
    assert_equal :main, Worker::QUEUE
  end

  def test_pops_jobs_from_a_queue
    encoded_job = Yajl::Encoder.encode(:class => 'TestJob', :args => [])

    redis = Redis.any_instance
    redis.expects(:lpop).with("resque:queue:#{Worker::QUEUE}").returns(encoded_job)

    Worker.work(:one_off => true)
  end

  # TODO: more tests here.
end
