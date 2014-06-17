require 'rspec'

require_relative '../lib/3scale/backend.rb'

RSpec.configure do |config|
  config.before :suite do
    ThreeScale::Backend.configure do |app_config|
      app_config.redis.nodes = [
        "127.0.0.1:7379",
        "127.0.0.1:7380",
      ]
    end
  end

  config.before :each do
    ThreeScale::Backend::Storage.instance(true).flushdb
    ThreeScale::Backend::Memoizer.reset!
  end
end
