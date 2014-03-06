require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StorageHelpersTest < Test::Unit::TestCase
  include Backend::Aggregator
  include TestHelpers::Sequences

  def setup
    @service_id = next_id
    @application = Application.save(:service_id => @service_id, :id => next_id, :state => :active)
    @metric = Metric.save(:service_id => @service_id, :id => next_id, :name => 'hits')
  end
end
