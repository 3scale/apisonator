ThreeScale::Backend::Aggregation.define do |rules|
  rules.add :service, :granularity => :eternity
  rules.add :service, :granularity => :month
  rules.add :service, :granularity => :week
  rules.add :service, :granularity => :day
  rules.add :service, :granularity => 6 * 60 * 60
  rules.add :service, :granularity => :hour
  rules.add :service, :granularity => 2 * 60

  rules.add :service, :cinstance, :granularity => :eternity
  rules.add :service, :cinstance, :granularity => :year
  rules.add :service, :cinstance, :granularity => :month
  rules.add :service, :cinstance, :granularity => :week
  rules.add :service, :cinstance, :granularity => :day
  rules.add :service, :cinstance, :granularity => 6 * 60 * 60
  rules.add :service, :cinstance, :granularity => :hour
  rules.add :service, :cinstance, :granularity => :minute, :expires_in => 60
end
