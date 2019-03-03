require 'benchmark/ips'

module ToCompactSBenchmark
  module Other
    def old_to_compact_s
      strftime('%Y%m%d%H%M%S').sub(/0{0,6}$/, '')
    end

    MODS = 61.times.map do |i|
      i % 10
    end.freeze
    private_constant :MODS

    DIVS = 61.times.map do |i|
      i / 10
    end.freeze
    private_constant :DIVS

    def new_to_compact_s
      s = year * 10000 +  month * 100 + day
      if sec != 0
        s = s * 100000 + hour * 1000 + min * 10
        MODS[sec] == 0 ? s + DIVS[sec] : s * 10 + sec
      elsif min != 0
        s = s * 1000 + hour * 10
        MODS[min] == 0 ? s + DIVS[min] : s * 10 + min
      elsif hour != 0
        s = s * 10
        MODS[hour] == 0 ? s + DIVS[hour] : s * 10 + hour
      else
        s
      end.to_s
    end
  end

  Time.send :include, Other

  def self.run
    tssec = Time.utc(2019, 02, 28, 0, 0, 1)
    tsmin = Time.utc(2019, 02, 28, 0, 1, 0)
    tshour = Time.utc(2019, 02, 28, 1, 0, 0)
    tsday = Time.utc(2019, 02, 28, 0, 0, 0)

    [tssec, tsmin, tshour, tsday].each_with_index do |ts, i|
      puts "#{i+1}. Comparison for #{ts}"
      Benchmark.ips do |x|
        x.report "old_to_compact_s #{ts.inspect}" do
          ts.old_to_compact_s
        end
        x.report "new_to_compact_s #{ts.inspect}" do
          ts.new_to_compact_s
        end
        x.compare!
      end

    end
  end
end

ToCompactSBenchmark.run
