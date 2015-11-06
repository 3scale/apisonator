## We use 'redis-hl' gem in this script.
## It's available in https://github.com/unleashed/redis-hl and it's also
## uploaded in geminabox.
## If there is no geminabox configured in the server where you want to execute
## the script, you can copy the .gem file there and do
## `gem install redis-hl-0.0.1.gem`.
##
## Usage: ruby get-stats 127.0.0.1 "stats/*/*:20120[0-7]*"
##

require 'redis-hl'

BATCHSIZE = 200

include RedisHL

$out = STDOUT
$err = STDERR

def print(s)
  $err.print s
  $err.flush
end

batch = BATCHSIZE
slice_size = 40
count = 0
numkeys = 0

now = Time.now
host, match, resumearg = ARGV

c = Client.new(Redis.new(host: host), config: { batch: batch, pause: 0.05 })

rinfo = resumearg ? Collection::ResumeInfo.new(resumearg) : Collection::ResumeInfo.new
e = c.root.each config: { match: match, build_key: false }, resumeinfo: rinfo

$err.puts "Logged on #{now.utc}\n\nRunning on #{host} with #{match} and " \
         "batchsize #{batch} resuming at #{resumearg ? resumearg : 0}\n\nINFO:\n"

c.info.info.sort.each do |k,v|
  $err.puts "#{k}: #{v}"
end

begin
  e.lazy.each_slice(slice_size) do |keys|
    print '.'
    sz = keys.size
    unless sz == 0
      vals = c.root.naked_mget(*keys)
      print 'M'
      $out.puts(keys.zip(vals).map { |k, v| "\"#{k}\":\"#{v}\"," }.join("\n"))
    end
    count -= 1 if count > 0
    sleep 0.01
    numkeys += sz
    rinfo.ack!(sz)
  end
rescue Interrupt
  print 'I'
  $err.puts "\n*** INTERRUPTED\n"
rescue Exception => e
  print "E\n#{e}\n"
  count += 1
  if count > 100
    $err.puts "\n*** RAISED #{e}\n"
    $err.flush
    raise e
  end
  sleep 6
  retry
ensure
  begin
    $err.puts "\nREADS: #{numkeys}\n\nRINFO: #{rinfo.inspect}\nFINAL INFO:\n"
    c.info.info.sort.each do |k,v|
      $err.puts "#{k}: #{v}"
    end
    $err.flush
  rescue Exception
  end
end
