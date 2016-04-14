# service_stats.rb
#
# This gives you data about the apps & metrics of a service.
#
# Load this script in an IRB session with Bundler:
#
# backend$ bundle exec irb
# irb> require './contrib/scripts/service_stats'
# irb> stats = ServiceStats.new 'someservice'
# irb> stats.get_app_metric_data period: :month, time: Time.mkdir(2016, 4)
#
# TODO: could also do the same with users.
#
require '3scale/backend'

include ThreeScale::Backend

class ServiceStats
  attr_reader :service_id, :metric_ids
  attr_accessor :io

  def initialize(service_id, io = STDERR)
    Service.load_by_id! service_id # checks that the Service exists
    @service_id, @io = service_id, io
    @appidset = Application.applications_set_key service_id
    @metric_ids = Metric.load_all_ids service_id
    @storage = Storage.instance
  end

  # Do not call this method unless you are willing to instantiate each app!
  def apps
    @apps || fill_in_apps
  end

  def app_ids
    @app_ids ||= storage.smembers @appidset
  end

  def get_app_metric_data(period: :year, time: Time.now)
    keys = []

    app_ids.product(metric_ids) do |app_id, metric_id|
      keys << Stats::Keys.usage_value_key(service_id, app_id, metric_id, period, time)
    end

    kv = {}
    io.puts "Getting keys"
    keys.each_slice(200) do |keyslice|
      vals = storage.mget keyslice
      keyslice.zip(vals) do |k, v|
        kv[k] = v
      end
      io.print '.'.freeze
      io.flush
    end
    io.puts
    kv.select { |_k, v| v }
  end

  private

  attr_reader :storage

  def fill_in_apps
    io.puts "Loading #{app_ids.size} apps, wait"
    @apps = {}
    app_ids.each_slice(10) do |app_ids_slice|
      app_ids_slice.each do |app_id|
        @apps[app_id] = Application.load(service_id, app_id)
        sleep 0.01
      end
      io.print '.'.freeze
      io.flush
    end
    io.puts
    @apps
  end
end
