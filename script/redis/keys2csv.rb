#!/usr/bin/env ruby

if ARGV.include?('-h') || ARGV.include?('--help')
  STDOUT.puts "usage:  #{$0} [--header] [--with-keys]\n\n" \
    "\tWill take stats keys from stdin and output CSV to stdout\n\n" \
    "\tKeys are expected to have a JSON-ish format on each line:\n\n" \
    "\t\t\"key\":\"value\",\n\n" \
    "\tKeys are expected to start with a namespace such as \"stats\"\n" \
    "\tand forward slashes separating fields with values.\n" \
    "\tFields and values are expected to be separated by colons \":\"\n" \
    "\tand curly braces and the literal \"N/A\" will be stripped out:\n\n" \
    "\t\t\"stats/{service:123}/cinstance:234/day:20151130\":\"34\"\n\n" \
    "\tUnrecognized keys will be sent to stderr.\n"
  exit 0
end

class StatsKeys2CSV
  DATE_COLS = [
    'year'.freeze,
    'month'.freeze,
    'day'.freeze,
    'hour'.freeze,
    'minute'.freeze,
  ].freeze
  PERIODS = [
    *DATE_COLS,
    'week'.freeze,
    'eternity'.freeze,
  ].freeze
  NON_DATE_PERIODS = (PERIODS - DATE_COLS).freeze
  ALL_COLUMNS = [
    *DATE_COLS,
    'period'.freeze,
    'service'.freeze,
    'cinstance'.freeze,
    'uinstance'.freeze,
    'metric'.freeze,
    'response_code'.freeze,
    'value'.freeze,
  ].freeze
  REQUIRED_COLS = [
    *DATE_COLS,
    'period'.freeze,
    'service'.freeze,
    'value'.freeze,
  ].freeze

  attr_reader :input, :output, :error

  def initialize(input: STDIN, output: STDOUT, error: STDERR, header: false, keys: false)
    @input = input
    @output = output
    @error = error
    @keys = keys
    @errored = false
    class << self
      alias_method :_gen_csv, :gen_csv
      def gen_csv(hash)
        _gen_csv(hash) + " # #{@line.chomp(',')}"
      end
    end if keys
    @output.puts('# ' + ALL_COLUMNS.map(&:to_s).join(',')) if header
  end

  def to_csv!
    @input.each_line do |line|
      line.chomp!
      # some keys have things like "field1:xxx/uinstance:N/A/field3:yyy" WTF.
      line.gsub!(/:N\/A/, ':'.freeze)
      @line = line
      h = line2hash line

      if REQUIRED_COLS.all? { |col| h.has_key?(col) } && (h.keys - ALL_COLUMNS).empty?
        output.puts gen_csv(h)
      else
        @errored = true
        error.puts line
      end
    end
  end

  def errored?
    @errored
  end

  private

  def prepare_str_from(line)
    _, key, _, val, *_ = line.split('"')
    "#{key.gsub(/[\{\}]/, '')}/value:#{val}"
  end

  def str2ary(str)
    str.split('/')[1..-1].map do |kv|
      kv.split(':')
    end
  end

  def gen_csv(hash)
    ALL_COLUMNS.map do |col|
      hash[col].to_s
    end.join(',')
  end

  def line2hash(line)
    h = Hash[str2ary(prepare_str_from line)]
    fix_dates_and_periods(h)
  end

  def fix_dates_and_periods(hash)
    period = hash.keys.find { |k| PERIODS.include? k }
    if period
      hash['period'.freeze] = period
      period_val = hash[period].dup
      hash['year'.freeze] = period_val.slice! 0, 4
      ['month'.freeze, 'day'.freeze, 'hour'.freeze, 'minute'.freeze].each do |p|
        hash[p] = period_val.slice! 0, 2
        hash[p] = nil if hash[p].empty?
      end
      NON_DATE_PERIODS.each { |ndp| hash.delete ndp }
    end
    hash
  end
end

sk2csv = StatsKeys2CSV.new header: ARGV.include?('--header'), keys: ARGV.include?('--with-keys')
sk2csv.to_csv!

exitval = if sk2csv.errored?
            1
          else
            0
          end

exit exitval
