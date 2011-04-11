require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class CacheTest < Test::Unit::TestCase

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
		seed_data()
  end

  




end
