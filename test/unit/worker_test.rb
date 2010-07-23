require File.dirname(__FILE__) + '/../test_helper'

class WorkerTest < Test::Unit::TestCase
  def setup
  end

  def test_works_off_queued_job
    job = stub('job', :queue => Worker::QUEUE, :payload => 'foo')
    job.expects(:perform)

    Resque::Job.stubs(:reserve).returns(job).then.returns(nil)

    Worker.work(:one_off => true)
  end

  def test_waits_if_queue_is_empty
    Resque::Job.stubs(:reserve).returns(nil)

    worker = Worker.new(:one_off => true)
    worker.expects(:sleep)

    worker.work
  end

  def test_handles_job_failures
    job = stub('job', :queue => Worker::QUEUE, :payload => 'foo')
    job.stubs(:perform).raises('Boo!')
    job.expects(:fail).with(responds_with(:message, 'Boo!'))

    Resque::Job.stubs(:reserve).returns(job).then.returns(nil)

    Worker.work(:one_off => true)
  end
end
