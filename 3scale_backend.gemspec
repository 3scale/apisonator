# encoding: UTF-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require '3scale/backend/version'

Gem::Specification.new do |s|
  s.name        = '3scale_backend'
  s.version     = ThreeScale::Backend::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Adam Ciganek", "Tiago Macedo", "Josep M. Pujol",
                   "Toni Reina", "Wojciech Ogrodowczyk",
                   "Alejandro Martinez Ruiz", "David Ortiz Lopez"]
  s.email       = 'backend@3scale.net'
  s.homepage    = 'http://www.3scale.net'
  s.summary     = '3scale web service management system backend'
  s.description = 'This gem provides a daemon that handles authorization and reporting of web services managed by 3scale.'
  s.license     = 'Propietary'

  s.required_ruby_version     = ">= 2.1.0"
  s.required_rubygems_version = ">= 1.3.7"

  s.add_dependency 'rake',                      '10.4.2'
  s.add_dependency 'daemons',                   '1.1.9'
  s.add_dependency 'builder',                   '3.2.2'
  s.add_dependency 'hiredis',                   '0.6.0'
  s.add_dependency 'redis',                     '3.2.1'
  s.add_dependency 'resque',                    '1.23.0'
  s.add_dependency 'rack',                      '1.6.4'
  s.add_dependency 'airbrake',                  '4.3.0'
  s.add_dependency 'tilt',                      '1.4.1'
  s.add_dependency 'sinatra',                   '1.4.6'
  s.add_dependency 'sinatra-contrib',           '1.4.6'
  s.add_dependency 'redis-namespace',           '1.5.1'
  s.add_dependency 'influxdb',                  '0.1.8'
  s.add_dependency 'cubert-client',             '0.0.12'

  s.files = Dir.glob('{lib,bin,app,config}/**/*')
  s.files << 'README.md'
  s.files << 'Rakefile'
  s.files << 'config.ru'
  # Gemfile* and gemspec are included here to support
  # running Bundler at gem install time.
  s.files << 'Gemfile'
  s.files << 'Gemfile.lock'
  s.files << __FILE__

  s.executables  = ['3scale_backend', '3scale_backend_worker']
  s.require_path = 'lib'

  s.extensions = 'ext/mkrf_conf.rb'
end
