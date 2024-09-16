source 'https://rubygems.org'

gemspec

# C-API only gems
#
# It is useful to tag these because not all Ruby implementations support these
# kinds of gems. In particular, gems here have NO alternative non C-API
# implementations (ie. pure Ruby, java, etc).
#
platform :ruby do
  gem 'hiredis-client'
  gem 'yajl-ruby', '~> 1.4.3', require: 'yajl'
  gem 'pry-byebug', '~> 3', groups: [:development]
end

group :test do
  # Newer versions of rack-test don't work well with rspec-api-documentation.
  # See https://github.com/rack/rack-test/pull/223 &
  # https://github.com/zipmark/rspec_api_documentation/issues/342
  gem 'rack-test',     '= 0.8.2'

  gem 'benchmark-ips', '~> 2.7.2'
  gem 'mocha',         '~> 1.3'
  gem 'nokogiri',      '~> 1.16.5'
  gem 'pkg-config',    '~> 1.1.7'
  gem 'resque_unit',   '~> 0.4.4'
  gem 'test-unit',     '~> 3.5'
  gem 'resque_spec',   '~> 0.17.0'
  gem 'timecop',       '~> 0.9.1'
  gem 'rspec',         '~> 3.7.0', require: nil
  gem 'codeclimate-test-reporter', '~> 0.6.0', require: nil
  gem 'async-rspec'
end

group :development do
  gem 'sshkit'
  gem 'source2swagger', git: 'https://github.com/3scale/source2swagger', branch: 'backend'
  gem 'pry',      '~> 0.14'
  gem 'pry-doc',  '~> 1.1'
  gem 'license_finder', '~> 7.0'
end

group :development, :test do
  gem 'rspec_api_documentation', '~> 6.0'
end

# Default server by platform
gem 'puma', git: 'https://github.com/3scale/puma', branch: '3scale-4.3.9'
# gems required by the runner
gem 'gli', '~> 2.16.1', require: nil
# Workers
gem 'daemons', '= 1.2.4'

# Production gems
gem 'rake', '~> 13.0'
gem 'builder', '= 3.2.3'
gem 'redis', '~> 5.0'
gem 'resque', '~> 2.6.0'
gem 'redis-namespace', '~>1.8'
gem 'rack', '~> 2.2.8'
gem 'sinatra', '~> 2.2.4'
gem 'sinatra-contrib', '~> 2.2.4'
gem "opentelemetry-sdk", "~> 1.5"
gem "opentelemetry-instrumentation-sinatra", "~> 0.24.1"
gem "opentelemetry-exporter-otlp", "~> 0.29.0"
# Optional external error logging services
gem 'bugsnag', '~> 6', require: nil
gem 'yabeda-prometheus', '~> 0.5.0'
gem 'async-redis', '~> 0.7.0'
gem 'async-pool', '~> 0.3.12'
gem 'falcon', '~> 0.35'
gem 'webrick', '~> 1.8'


gem 'dotenv'
