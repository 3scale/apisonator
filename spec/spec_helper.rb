require 'rspec'

require_relative '../lib/3scale/backend.rb'

RSpec.configure do |config|
  config.before :each do
    ThreeScale::Backend::Storage.instance(true).flushdb
    ThreeScale::Backend::Memoizer.reset!
  end
end
