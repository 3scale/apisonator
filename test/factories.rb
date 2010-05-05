require File.dirname(__FILE__) + '/../lib/3scale/backend/models'
include ThreeScale::Backend

Factory.define(:account) do |factory|
end

Factory.define(:provider_account, :parent => :account) do |factory|
end

Factory.define(:buyer_account, :parent => :account) do |factory|
end

Factory.define(:service) do |factory|
  factory.association :account, :factory => :provider_account
  factory.state 'published'
end

Factory.define(:plan) do |factory|
  factory.association :service
  factory.state 'published'
end

Factory.define(:contract) do |factory|
  factory.association :buyer_account
  factory.association :plan
  factory.state 'live'
end
