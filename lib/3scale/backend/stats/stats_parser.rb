module ThreeScale
  module Backend
    module Stats
      class StatsParser
        # This parser converts a stats key of Redis into a Hash
        # This is an example of stats key that this parser converts:
        # "stats/{service:1006}/cinstance:a60/metric:255/week:20151130"

        # This class contains code stolen from Alex's script:
        # /script/redis/stats_keys_2_csv
        # We can think about unifying code later.

        DATE_COLS = [
            'year'.freeze,
            'month'.freeze,
            'day'.freeze,
            'hour'.freeze,
            'minute'.freeze,
        ].freeze
        private_constant :DATE_COLS

        PERIODS = [
            *DATE_COLS,
            'week'.freeze,
            'eternity'.freeze,
        ].freeze
        private_constant :PERIODS

        NON_DATE_PERIODS = (PERIODS - DATE_COLS).freeze
        private_constant :NON_DATE_PERIODS

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
        private_constant :ALL_COLUMNS

        REQUIRED_COLS = [
            *DATE_COLS,
            'period'.freeze,
            'service'.freeze,
            'value'.freeze,
        ].freeze
        private_constant :REQUIRED_COLS

        StatsKeyValueInvalid = Class.new(ThreeScale::Backend::Error)

        class << self

          def parse(stats_key, value)
            key_value_to_hash(stats_key, value)
          end

          private

          def key_value_to_hash(key,value)
            key_value = ("\"#{key}\":\"#{value}\"")

            # some keys have things like "field1:xxx/uinstance:N/A/field3:yyy" WTF.
            key_value.gsub!(/:N\/A/, ':'.freeze)

            h = Hash[str2ary(prepare_str_from(key_value))]

            result = fix_dates_and_periods(h)

            all_required_columns = REQUIRED_COLS.all? { |col| h.has_key?(col) }
            no_extra_columns = (h.keys - ALL_COLUMNS).empty?

            unless all_required_columns && no_extra_columns
              raise StatsKeyValueInvalid, "Error parsing #{key_value}"
            end

            Hash[result.map{ |k, v| [k.to_sym, v] }]
          end

          def prepare_str_from(line)
            _, key, _, val, *_ = line.split('"')
            "#{key.gsub(/[\{\}]/, '')}/value:#{val}"
          end

          def str2ary(str)
            str.split('/')[1..-1].map do |kv|
              kv.split(':')
            end
          end

          def fix_dates_and_periods(hash)
            period = hash.keys.find { |k| PERIODS.include? k }
            if period
              hash['period'.freeze] = period
              period_val = (period == 'eternity' ? '' : hash[period].dup)

              DATE_COLS.each do |date_col|
                hash[date_col] = if date_col == 'year'
                                   period_val.slice! 0, 4
                                 else
                                   period_val.slice! 0, 2
                                 end
                hash[date_col] = nil if hash[date_col].empty?
              end
              NON_DATE_PERIODS.each { |ndp| hash.delete ndp }
            end
            hash
          end

        end
      end
    end
  end
end
