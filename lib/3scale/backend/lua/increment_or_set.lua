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


local service_prefix     = "stats/{service:" .. service_id .. "}"
local application_prefix = service_prefix .. "/cinstance:" .. application_id

local action
if op_type == 'set' then
   action = 'set'
else
   action =  'incrby'
end

local service_metric_prefix = service_prefix .. "/metric:" .. metric_id
local application_metric_prefix = application_prefix .. "/metric:" .. metric_id
local prefixes = { application_metric_prefix }

if user_id ~= nil then
   local user_prefix     =  service_prefix .. "/uinstance:" .. user_id
   local user_metric_prefix = user_prefix .. "/metric:" .. metric_id
   prefixes['user_metric_prefix'] =  user_metric_prefix
end

local granularities = { eternity=timestamp_et, year=timestamp_year,
			month=timestamp_month, week=timestamp_week, day=timestamp_day,
			hour=timestamp_hour , minute=timestamp_minute }

-- -- eternity
-- redis.call(action, key, value)

-- granularities
for granularity,timestamp in pairs(granularities) do
   for i,prefix in ipairs(prefixes) do
      local key = prefix ..  timestamp
      redis.call(action,key,value)
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
   redis.call(action,key,value)
end

-- redis.call(action,key,value)
