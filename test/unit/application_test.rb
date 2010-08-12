require File.dirname(__FILE__) + '/../test_helper'

class ApplicationTest < Test::Unit::TestCase
  def test_active_returns_true_if_application_is_in_active_state
    application = Application.new(:state => :active)
    assert application.active?
  end

  def test_active_returns_false_if_application_is_in_suspended_state
    application = Application.new(:state => :suspended)
    assert !application.active?
  end
end
