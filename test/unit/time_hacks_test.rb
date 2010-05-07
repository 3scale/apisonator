require File.dirname(__FILE__) + '/../test_helper'

class TimeHacksTest < Test::Unit::TestCase
  def test_beginning_of_cycle_with_60_minutes
    assert_equal Time.utc(2009, 6, 11, 13, 00),
                 Time.utc(2009, 6, 11, 13, 45).beginning_of_cycle(60 * 60) 
  end

  def test_beginning_of_cycle_with_30_minutes
    assert_equal Time.utc(2009, 6, 11, 13, 00),
                 Time.utc(2009, 6, 11, 13, 15).beginning_of_cycle(30 * 60)
    
    assert_equal Time.utc(2009, 6, 11, 13, 30),
                 Time.utc(2009, 6, 11, 13, 45).beginning_of_cycle(30 * 60)
  end

  def test_beginning_of_cycle_with_24_hours 
    assert_equal Time.utc(2009, 6, 11, 00, 00),
                 Time.utc(2009, 6, 11, 13, 45).beginning_of_cycle(24 * 60 * 60)
  end

  def test_beginning_of_cycle_with_6_hours    
    assert_equal Time.utc(2009, 6, 11, 00, 00),
                 Time.utc(2009, 6, 11,  4, 00).beginning_of_cycle(6 * 60 * 60)
    
    assert_equal Time.utc(2009, 6, 11,  6, 00),
                 Time.utc(2009, 6, 11,  8, 00).beginning_of_cycle(6 * 60 * 60)
    
    assert_equal Time.utc(2009, 6, 11, 12, 00),
                 Time.utc(2009, 6, 11, 14, 00).beginning_of_cycle(6 * 60 * 60)
  end

  def test_beginning_of_cycle_with_minute
    assert_equal Time.utc(2009, 6, 11, 13, 30), 
                 Time.utc(2009, 6, 11, 13, 30, 29).beginning_of_cycle(:minute)
  end
  
  def test_beginning_of_cycle_with_hour
    assert_equal Time.utc(2009, 6, 11, 13, 00), 
                 Time.utc(2009, 6, 11, 13, 30).beginning_of_cycle(:hour)
  end

  def test_beginning_of_cycle_with_day
    assert_equal Time.utc(2009, 6, 11), 
                 Time.utc(2009, 6, 11, 13, 30).beginning_of_cycle(:day)
  end

  def test_beginning_of_cycle_with_week    
    assert_equal Time.utc(2009, 6,  8), 
                 Time.utc(2009, 6, 11, 13, 30).beginning_of_cycle(:week)
  end

  def test_beginning_of_cycle_with_month
    assert_equal Time.utc(2009, 6,  1), 
                 Time.utc(2009, 6, 11, 13, 30).beginning_of_cycle(:month)
  end

  def test_beginning_of_cycle_with_year    
    assert_equal Time.utc(2009, 1,  1), 
                 Time.utc(2009, 6, 11, 13, 30).beginning_of_cycle(:year)
  end

  def test_to_compact_s
    assert_equal '20091103123455', Time.utc(2009, 11,  3, 12, 34, 55).to_compact_s
    assert_equal '200911031234',   Time.utc(2009, 11,  3, 12, 34,  0).to_compact_s
    assert_equal '2009110312',     Time.utc(2009, 11,  3, 12,  0,  0).to_compact_s
    assert_equal '20091103',       Time.utc(2009, 11,  3,  0,  0,  0).to_compact_s
    assert_equal '20091110',       Time.utc(2009, 11, 10,  0,  0,  0).to_compact_s
  end

  def test_parse_to_utc_with_input_without_offset
    assert_equal Time.utc(2010, 5, 7, 17, 28, 12), Time.parse_to_utc('2010-05-07 17:28:12')
  end
  
  def test_parse_to_utc_with_input_with_offset
    assert_equal Time.utc(2010, 5, 7, 13, 28, 12), Time.parse_to_utc('2010-05-07 17:28:12 +0400')
  end

  def test_parse_to_utc_returns_nil_on_invalid_input
    assert_nil Time.parse_to_utc('choke on this!')
  end
end
