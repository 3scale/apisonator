require File.dirname(__FILE__) + '/../test_helper'

class WorkerTest < Test::Unit::TestCase
  def setup
  end

  def test_queue_name
    assert_equal :main, Worker::QUEUE
  end

  # TODO: more tests here.
end
