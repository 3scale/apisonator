# A helper to match on fields of a log line
#
# Use methods with a "match_" prefix to have a regular expression generated
# that will be suitable for use with RSpec.
#
# Instantiate with the regexp-escaped string representation of fields and the
# field separator.
module SpecHelpers
  class LoglineMatcher
    attr_reader :field, :sep, :logline_start, :logline_end

    def initialize(field: '[^\s]+', sep: '\s', logline_start: '\A', logline_end: '\n\z')
      @field = field
      @sep = sep
      @logline_start = logline_start
      @logline_end = logline_end
    end

    def previous_fields(min_times, max_times = nil)
      "(#{field}#{sep}+)" + times(min_times, max_times)
    end

    def following_fields(min_times, max_times = nil)
      "(#{sep}+#{field})" + times(min_times, max_times)
    end

    def n_fields(n, s)
      if n > 0
        s << previous_fields(n-1, n-1) + field
      end
    end

    def at_least_n_fields(n, s)
      if n > 0
        n_fields(n-1, s)
        s << following_fields(0)
      end
    end

    def positional_field(field, prev_fields, follow_fields, s)
      if prev_fields
        s << previous_fields(prev_fields[0], prev_fields[1])
      end
      s << field
      if follow_fields
        s << following_fields(follow_fields[0], follow_fields[1])
      end
    end

    def a_field(field, s)
      positional_field(field, [0], [0], s)
    end

    def method_missing(m, *args, &blk)
      ms = m.to_s
      if ms.start_with?('match_')
        mname = ms['match_'.size..-1]
        if respond_to?(mname)
          define_singleton_method m do |*args_, &blk_|
            Regexp.new(logline_re do |s|
              send(mname, *args_, s, &blk_)
            end)
          end
          return public_send m, *args, &blk
        end
      end
      super
    end

    def respond_to_missing?(m, include_all)
      ms = m.to_s
      ms.start_with?('match_') && respond_to?(ms['match_'.size..-1], include_all)
    end

    private

    def logline_re(&blk)
      s = logline_start
      blk.call s
      s << logline_end
    end

    # regexp repetition matching suffixes for the specified amount of times
    def times(min_times, max_times)
      if max_times.nil?
        if min_times.zero?
          '*'
        elsif min_times == 1
          '+'
        else
          "{#{min_times},}"
        end
      elsif min_times == max_times
        if min_times == 1
          '?'
        else
          "{#{min_times}}"
        end
      else
        "{#{min_times},#{max_times}}"
      end
    end
  end
end
