require 'active_record'

ActiveRecord::Base.establish_connection(ThreeScale::Backend.configuration.sql)

require '3scale/backend/models/account'
require '3scale/backend/models/contract'
require '3scale/backend/models/metric'
require '3scale/backend/models/plan'
require '3scale/backend/models/service'
