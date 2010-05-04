require File.dirname(__FILE__) + '/../test_helper'

class RouteTest < Test::Unit::TestCase
  def test_matches_method_and_path
    env = {'PATH_INFO' => '/foo', 'REQUEST_METHOD' => 'GET'}
    assert Route.new(:get, '/foo', lambda {}).matches?(env)
  end

  def test_does_not_match_when_method_differs
    env = {'PATH_INFO' => '/foo', 'REQUEST_METHOD' => 'GET'}
    assert !Route.new(:post, '/foo', lambda {}).matches?(env)
  end
  
  def test_does_not_match_when_path_differs
    env = {'PATH_INFO' => '/foo', 'REQUEST_METHOD' => 'GET'}
    assert !Route.new(:get, '/bar', lambda {}).matches?(env)
  end
end
