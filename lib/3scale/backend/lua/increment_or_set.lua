local op_type = ARGV[1]
local service_id = ARGV[2]
local application_id = ARGV[3]
local metric_id = ARGV[4]
local user_id = ARGV[5]
local value = ARGV[6]
local timestamp_et = ARGV[7]
local timestamp_year = ARGV[8]
local timestamp_month = ARGV[9]
local timestamp_week = ARGV[10]
local timestamp_day = ARGV[11]
local timestamp_hour = ARGV[12]
local timestamp_minute = ARGV[13]

local cassandra_enabled = ARGV[14]
local cassandra_bucket =  ARGV[15]

local service_prefix     = "stats/{service:" .. service_id .. "}"
local application_prefix = service_prefix .. "/cinstance:" .. application_id

local action = ''
if op_type == 'set' then
   action = 'set'
else
   action =  'incrby'
end

local service_metric_prefix = service_prefix .. "/metric:" .. metric_id
local application_metric_prefix = application_prefix .. "/metric:" .. metric_id
local prefixes = { application_metric_prefix }




if not tostring(user_id):find("^%s*$") then
   local user_prefix     =  service_prefix .. "/uinstance:" .. user_id
   local user_metric_prefix = user_prefix .. "/metric:" .. metric_id
   table.insert(prefixes,  user_metric_prefix)
end

local granularities = { eternity=timestamp_et, year=timestamp_year,
			month=timestamp_month, week=timestamp_week, day=timestamp_day,
			hour=timestamp_hour , minute=timestamp_minute }

local set_keys = {}

local is_true = function(str)
   return (str == "true" )
end

local add_to_copied_keys =  function(action, cassandra_bucket, key, value)
   if is_true(cassandra_enabled) then
      redis.call('sadd', ("keys_changed:" .. cassandra_bucket), key)
      if action == 'set' then
	 table.insert(set_keys, {key, value})
      else
	 redis.call(action, key, value)
	 redis.call('incrby', "copied:".. cassandra_bucket .. ":" .. key, value)
      end
   else
      redis.call(action, key, value)
   end
end

for granularity,timestamp in pairs(granularities) do
   for i,prefix in ipairs(prefixes) do
      local key = prefix .. timestamp
      add_to_copied_keys(action, cassandra_bucket, key, value)
      if granularity == 'minute'  then
	 redis.call('expire', key, 180)

      end
   end
end

granularities["year"] = nil
granularities["minute"] = nil
for granularity,timestamp in pairs(granularities) do
   local prefix = service_metric_prefix
   local key = prefix .. timestamp
   add_to_copied_keys(action, cassandra_bucket, key, value)
end

return set_keys
