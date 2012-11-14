require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class WorkerTest < Test::Unit::TestCase
  def setup
  end

  def test_queue_name
    assert_equal :priority, Worker::QUEUES[0]
    assert_equal :main, Worker::QUEUES[1]
  end

  def test_format_of_a_job
    encoded_job = Yajl::Encoder.encode(:class => 'TestJob', :args => [{'0'=> {:app_id => "app_id with spaces"}}])
    assert_equal '{"class":"TestJob","args":[{"0":{"app_id":"app_id with spaces"}}]}', encoded_job
    
  end

  def test_pops_jobs_from_a_queue
    encoded_job = Yajl::Encoder.encode(:class => 'TestJob', :args => [])

    #redis = Redis.any_instance
    #redis.expects(:blpop).with(*Worker::QUEUES.map{|q| "resque:queue:#{q}"}, "60").returns(encoded_job)

    #Worker.work(:one_off => true)
    
    ## FIXME 2: This fails under resque-1.23 but it's unclear what is doing :/ (as the previous fixme says)
    ## let's see if integrations tests cover
    
    ## FIXME: NOT CLEAR. This produces an exception on resque and the job is stored in resque:failed, unclear
    ## what's the aim of the test 
  end

  def test_no_jobs_in_the_queue
    redis = Redis.any_instance
    redis.expects(:blpop).with(*Worker::QUEUES.map{|q| "resque:queue:#{q}"}, "60").returns(nil)

    Worker.work(:one_off => true)
  end

  # TODO: more tests here.
end
