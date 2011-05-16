#! /usr/bin/env ruby
host="http://localhost:3001"
method="/transactions/authrep.xml"
provider_key="pkey"
app_id="app_id"
#usage="usage[method1]=1&usage[other]=3&usage[user_metric]=1"
usage="usage[hits]=1"
no_body=""
#no_body="no_body=true&"
user_id=""
user_id="&user_id=#{ARGV[0]}" unless ARGV[0].nil? || ARGV[0].empty? 

#str="wget -O /tmp/result.xml  \"#{host}#{method}?#{no_body}provider_key=#{provider_key}&app_id=#{app_id}&#{usage}#{user_id}\" -O /tmp/result.xml" 

str="curl -g -o /tmp/result.xml \"#{host}#{method}?#{no_body}provider_key=#{provider_key}&app_id=#{app_id}&#{usage}#{user_id}\""
puts "ACTION: #{str}"
puts ""

system str

puts "RESULTS"
puts "--------------------------------------------"
system "cat /tmp/result.xml"
puts ""
puts "--------------------------------------------"

