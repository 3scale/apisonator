#!/usr/bin/env ruby

require_relative 'stats_keys_2_csv'

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

sk2csv = StatsKeys2CSV.new header: ARGV.include?('--header'), keys: ARGV.include?('--with-keys')
sk2csv.to_csv!

exitval = if sk2csv.errored?
            1
          else
            0
          end

exit exitval
