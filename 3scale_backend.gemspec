# encoding: UTF-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require '3scale/backend/version'

Gem::Specification.new do |s|
  s.name        = '3scale_backend'
  s.version     = ThreeScale::Backend::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Adam Ciganek", "Tiago Macedo", "Wojciech Ogrodowczyk", "Josep M. Pujol", "Toni Reina"]
  s.email       = 'tiago@3scale.net'
  s.homepage    = 'http://www.3scale.net'
  s.summary     = '3scale web service management system backend'
  s.description = 'This gem provides a daemon that handles authorization and reporting of web services managed by 3scale.'
  s.license     = 'Propietary'

  s.required_ruby_version     = ">= 1.9.3"
  s.required_rubygems_version = ">= 1.3.7"

  s.add_dependency 'rake',                      '10.1.0'
  s.add_dependency 'builder',                   '2.1.2'
  s.add_dependency 'hiredis',                   '0.4.5'
  s.add_dependency 'redis',                     '3.0.2'
  s.add_dependency 'resque',                    '1.23.0'
  s.add_dependency 'rack',                      '1.5.2'
  s.add_dependency 'airbrake',                  '3.1.16'
  s.add_dependency 'tilt',                      '1.4.1'
  s.add_dependency 'sinatra',                   '1.4.5'
  s.add_dependency 'thin',                      '1.5.0'
  s.add_dependency 'yajl-ruby',                 '1.1.0'
  s.add_dependency 'rest-client',               '1.6.7'
  s.add_dependency 'redis-namespace',           '1.2.1'
  s.add_dependency 'mongo',                     '1.9.0'
  s.add_dependency 'bson_ext',                  '1.9.0'
  s.add_dependency '3scale_core',               '1.1.0'
  s.add_dependency 'redis-sentinel',            '1.4.4'

  s.files = Dir.glob('{lib,bin,app}/**/*')
  s.files << 'README.md'
  s.files << 'Rakefile'

  s.executables  = ['3scale_backend', '3scale_backend_worker']
  s.require_path = 'lib'
end
