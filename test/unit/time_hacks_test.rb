require File.dirname(__FILE__) + '/../test_helper'

class TimeHacksTest < Test::Unit::TestCase
  def test_beginning_of_cycle_with_60_minutes
    assert_equal Time.local(2009, 6, 11, 13, 00),
                 Time.local(2009, 6, 11, 13, 45).beginning_of_cycle(60 * 60) 
  end

  def test_beginning_of_cycle_with_30_minutes
    assert_equal Time.local(2009, 6, 11, 13, 00),
                 Time.local(2009, 6, 11, 13, 15).beginning_of_cycle(30 * 60)
    
    assert_equal Time.local(2009, 6, 11, 13, 30),
                 Time.local(2009, 6, 11, 13, 45).beginning_of_cycle(30 * 60)
  end

  def test_beginning_of_cycle_with_24_hours 
    assert_equal Time.local(2009, 6, 11, 00, 00),
                 Time.local(2009, 6, 11, 13, 45).beginning_of_cycle(24 * 60 * 60)
  end

  def test_beginning_of_cycle_with_6_hours    
    assert_equal Time.local(2009, 6, 11, 00, 00),
                 Time.local(2009, 6, 11,  4, 00).beginning_of_cycle(6 * 60 * 60)
    
    assert_equal Time.local(2009, 6, 11,  6, 00),
                 Time.local(2009, 6, 11,  8, 00).beginning_of_cycle(6 * 60 * 60)
    
    assert_equal Time.local(2009, 6, 11, 12, 00),
                 Time.local(2009, 6, 11, 14, 00).beginning_of_cycle(6 * 60 * 60)
  end

  def test_beginning_of_cycle_with_minute
    assert_equal Time.local(2009, 6, 11, 13, 30), 
                 Time.local(2009, 6, 11, 13, 30, 29).beginning_of_cycle(:minute)
  end
  
  def test_beginning_of_cycle_with_hour
    assert_equal Time.local(2009, 6, 11, 13, 00), 
                 Time.local(2009, 6, 11, 13, 30).beginning_of_cycle(:hour)
  end

  def test_beginning_of_cycle_with_day
    assert_equal Time.local(2009, 6, 11), 
                 Time.local(2009, 6, 11, 13, 30).beginning_of_cycle(:day)
  end

  def test_beginning_of_cycle_with_week    
    assert_equal Time.local(2009, 6,  8), 
                 Time.local(2009, 6, 11, 13, 30).beginning_of_cycle(:week)
  end

  def test_beginning_of_cycle_with_month
    assert_equal Time.local(2009, 6,  1), 
                 Time.local(2009, 6, 11, 13, 30).beginning_of_cycle(:month)
  end

  def test_beginning_of_cycle_with_year    
    assert_equal Time.local(2009, 1,  1), 
                 Time.local(2009, 6, 11, 13, 30).beginning_of_cycle(:year)
  end

  def test_to_compact_s
    assert_equal '20091103123455', Time.local(2009, 11,  3, 12, 34, 55).to_compact_s
    assert_equal '200911031234',   Time.local(2009, 11,  3, 12, 34,  0).to_compact_s
    assert_equal '2009110312',     Time.local(2009, 11,  3, 12,  0,  0).to_compact_s
    assert_equal '20091103',       Time.local(2009, 11,  3,  0,  0,  0).to_compact_s
    assert_equal '20091110',       Time.local(2009, 11, 10,  0,  0,  0).to_compact_s
  end
end
