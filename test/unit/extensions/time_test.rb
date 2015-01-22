require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Extensions
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
      assert_equal Time.utc(2009, 6, 8),
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

    def test_beginning_of_cycle_with_eternity
      assert_equal Time.utc(1970, 1,  1),
                   Time.utc(2009, 6, 11, 13, 30).beginning_of_cycle(:eternity)
    end

    def test_end_of_cycle_with_minute
      assert_equal Time.utc(2010, 5, 17, 13, 31),
                   Time.utc(2010, 5, 17, 13, 30, 17).end_of_cycle(:minute)
    end

    def test_end_of_cycle_with_minute_in_the_last_minute_of_a_hour
      assert_equal Time.utc(2010, 5, 17, 14),
                   Time.utc(2010, 5, 17, 13, 59, 17).end_of_cycle(:minute)
    end

    def test_end_of_cycle_with_minute_in_the_last_minute_of_a_day
      assert_equal Time.utc(2010, 5, 18),
                   Time.utc(2010, 5, 17, 23, 59, 17).end_of_cycle(:minute)
    end

    def test_end_of_cycle_with_minute_in_the_last_minute_of_a_month
      assert_equal Time.utc(2010, 6, 1),
                   Time.utc(2010, 5, 31, 23, 59, 17).end_of_cycle(:minute)
    end

    def test_end_of_cycle_with_minute_in_the_last_minute_of_a_year
      assert_equal Time.utc(2011, 1, 1),
                   Time.utc(2010, 12, 31, 23, 59, 17).end_of_cycle(:minute)
    end

    def test_end_of_cycle_with_hour
      assert_equal Time.utc(2010, 5, 17, 14, 0),
                   Time.utc(2010, 5, 17, 13, 30).end_of_cycle(:hour)
    end

    def test_end_of_cycle_with_hour_in_the_last_hour_of_a_year
      assert_equal Time.utc(2011, 1, 1),
                   Time.utc(2010, 12, 31, 23, 30).end_of_cycle(:hour)
    end

    def test_end_of_cycle_with_hour_in_the_last_hour_of_a_month
      assert_equal Time.utc(2010, 6, 1),
                   Time.utc(2010, 5, 31, 23, 30).end_of_cycle(:hour)
    end

    def test_end_of_cycle_with_hour_in_the_last_hour_of_a_day
      assert_equal Time.utc(2010, 5, 18),
                   Time.utc(2010, 5, 17, 23, 30).end_of_cycle(:hour)
    end

    def test_end_of_cycle_with_day
      assert_equal Time.utc(2010, 5, 18),
                   Time.utc(2010, 5, 17, 13, 30).end_of_cycle(:day)
    end

    def test_end_of_cycle_with_day_in_the_last_day_of_a_month
      assert_equal Time.utc(2010, 6, 1),
                   Time.utc(2010, 5, 31, 13, 30).end_of_cycle(:day)
    end

    def test_end_of_cycle_with_day_in_the_last_day_of_a_year
      assert_equal Time.utc(2011, 1, 1),
                   Time.utc(2010, 12, 31, 13, 30).end_of_cycle(:day)
    end

    def test_end_of_cycle_with_week
      assert_equal Time.utc(2010, 5, 24),
                   Time.utc(2010, 5, 17, 13, 30).end_of_cycle(:week)
    end

    def test_end_of_cycle_with_week_in_the_last_week_of_a_month
      assert_equal Time.utc(2010, 5, 3),
                   Time.utc(2010, 4, 29, 13, 30).end_of_cycle(:week)
    end

    def test_end_of_cycle_with_week_in_the_last_week_of_a_year
      assert_equal Time.utc(2012, 1, 2),
                   Time.utc(2011, 12, 30, 13, 30).end_of_cycle(:week)
    end

    def test_end_of_cycle_with_month
      assert_equal Time.utc(2010, 6, 1),
                   Time.utc(2010, 5, 17, 13, 30).end_of_cycle(:month)
    end

    def test_end_of_cycle_with_month_in_the_last_month_of_a_year
      assert_equal Time.utc(2011, 1, 1),
                   Time.utc(2010, 12, 4, 13, 30).end_of_cycle(:month)
    end

    def test_end_of_cycle_with_year
      assert_equal Time.utc(2011, 1, 1),
                   Time.utc(2010, 5, 17, 13, 30).end_of_cycle(:year)
    end

    def test_end_of_cycle_with_eternity
      assert_equal Time.utc(9999, 12, 31),
                   Time.utc(2010, 5, 17, 13, 30).end_of_cycle(:eternity)
    end

    def test_to_compact_s
      assert_equal '20091103123455', Time.utc(2009, 11,  3, 12, 34, 55).to_compact_s
      assert_equal '200911031234',   Time.utc(2009, 11,  3, 12, 34,  0).to_compact_s
      assert_equal '2009110312',     Time.utc(2009, 11,  3, 12,  0,  0).to_compact_s
      assert_equal '20091103',       Time.utc(2009, 11,  3,  0,  0,  0).to_compact_s
      assert_equal '20091110',       Time.utc(2009, 11, 10,  0,  0,  0).to_compact_s
      assert_equal '21000101',       Time.utc(2100, 1, 1,  0,  0,  0).to_compact_s
    end

    def test_end_of_cycle_with_to_compact_s
      ## back zeros are removed,
      ## instead of  '200910301020' it does '20091030102'
      assert_equal '20091030102' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:minute).to_compact_s
      assert_equal '200910301' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:hour).to_compact_s
      ## WTF the days do not remove the zeros!! :-/
      assert_equal '20091030' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:day).to_compact_s
      assert_equal '20091026' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:week).to_compact_s
      ## and the month does not remove, but places at the beggining of the month
      assert_equal '20091001' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:month).to_compact_s
      ## same for year, festival
      assert_equal '20090101' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:year).to_compact_s

      assert_equal '20091030102000' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:minute).to_not_compact_s
      assert_equal '20091030100000' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:hour).to_not_compact_s
      assert_equal '20091030000000' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:day).to_not_compact_s
      assert_equal '20091026000000' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:week).to_not_compact_s
      assert_equal '20091001000000' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:month).to_not_compact_s
      assert_equal '20090101000000' , Time.utc(2009, 10,  30, 10, 20,  40).beginning_of_cycle(:year).to_not_compact_s
    end


    def test_parse_to_utc_with_input_without_offset
      assert_equal Time.utc(2010, 5, 7, 17, 28, 12), Time.parse_to_utc('2010-05-07 17:28:12')
    end

    def test_parse_to_utc_with_input_with_offset
      assert_equal Time.utc(2010, 5, 7, 13, 28, 12), Time.parse_to_utc('2010-05-07 17:28:12 +0400')
    end

    def test_parse_to_utc_with_input_with_offset_with_other_format
      assert_equal Time.utc(2010, 5, 7, 12+8, 28, 12), Time.parse_to_utc('2010-05-07 12:28:12 PST')
    end

    def test_parse_to_utc_returns_nil_on_invalid_input
      assert_nil Time.parse_to_utc(nil)
      assert_nil Time.parse_to_utc('')
      assert_nil Time.parse_to_utc(0)
      assert_nil Time.parse_to_utc({:a => 10})
      assert_nil Time.parse_to_utc('0')
      assert_nil Time.parse_to_utc('2011/11')
      assert_nil Time.parse_to_utc('2011/18/20')
      assert_nil Time.parse_to_utc('choke on this!')
    end

    def test_beginning_of_bucket
      assert_equal '20091103123456', Time.utc(2009, 11,  3, 12, 34, 56).beginning_of_bucket(1).to_not_compact_s
      assert_equal '20091103123456', Time.utc(2009, 11,  3, 12, 34, 56).beginning_of_bucket(2).to_not_compact_s
      assert_equal '20091103123454', Time.utc(2009, 11,  3, 12, 34, 56).beginning_of_bucket(3).to_not_compact_s
      assert_equal '20091103123455', Time.utc(2009, 11,  3, 12, 34, 56).beginning_of_bucket(5).to_not_compact_s
      assert_equal '20091103123450', Time.utc(2009, 11,  3, 12, 34, 56).beginning_of_bucket(10).to_not_compact_s
      assert_equal '20091103123440', Time.utc(2009, 11,  3, 12, 34, 56).beginning_of_bucket(20).to_not_compact_s
      assert_equal '20091103123430', Time.utc(2009, 11,  3, 12, 34, 56).beginning_of_bucket(30).to_not_compact_s

      assert_equal '20091103123400', Time.utc(2009, 11,  3, 12, 34, 00).beginning_of_bucket(1).to_not_compact_s
      assert_equal '20091103123400', Time.utc(2009, 11,  3, 12, 34, 00).beginning_of_bucket(2).to_not_compact_s
      assert_equal '20091103123400', Time.utc(2009, 11,  3, 12, 34, 00).beginning_of_bucket(3).to_not_compact_s
      assert_equal '20091103123400', Time.utc(2009, 11,  3, 12, 34, 00).beginning_of_bucket(5).to_not_compact_s
      assert_equal '20091103123400', Time.utc(2009, 11,  3, 12, 34, 00).beginning_of_bucket(10).to_not_compact_s
      assert_equal '20091103123400', Time.utc(2009, 11,  3, 12, 34, 00).beginning_of_bucket(20).to_not_compact_s
      assert_equal '20091103123400', Time.utc(2009, 11,  3, 12, 34, 00).beginning_of_bucket(30).to_not_compact_s

      assert_equal '21000101000000', Time.utc(2100, 01,  01, 0, 0, 1).beginning_of_bucket(30).to_not_compact_s
      assert_equal '21000101000030', Time.utc(2100, 01,  01, 0, 0, 31).beginning_of_bucket(3).to_not_compact_s
      assert_equal '21000101000035', Time.utc(2100, 01,  01, 0, 0, 36).beginning_of_bucket(5).to_not_compact_s

    end

    def test_exception_on_beginning_of_bucket
      assert_raise Exception do
        assert_equal '20091103123456', Time.utc(2009, 11,  3, 12, 34, 56).beginning_of_bucket(0).to_not_compact_s
      end

      assert_raise Exception do
        assert_equal '20091103123456', Time.utc(2009, 11,  3, 12, 34, 56).beginning_of_bucket(-1).to_not_compact_s
      end

      assert_raise Exception do
        assert_equal '20091103123456', Time.utc(2009, 11,  3, 12, 34, 56).beginning_of_bucket(60).to_not_compact_s
      end

      assert_raise Exception do
        assert_equal '20091103123456', Time.utc(2009, 11,  3, 12, 34, 56).beginning_of_bucket(3.5).to_not_compact_s
      end
    end
  end
end
