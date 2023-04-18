# encoding: UTF-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require '3scale/backend/version'

Gem::Specification.new do |s|
  s.name        = 'apisonator'
  s.version     = ThreeScale::Backend::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Adam Ciganek", "Tiago Macedo", "Josep M. Pujol",
                   "Toni Reina", "Wojciech Ogrodowczyk",
                   "Alejandro Martinez Ruiz", "David Ortiz Lopez",
                   "Eguzki Astiz Lezaun", "Miguel Soriano Domenech"]
  s.email       = '3scale-engineering@redhat.com'
  s.homepage    = 'https://www.redhat.com/en/technologies/jboss-middleware/3scale'
  s.summary     = '3scale web service management system backend'
  s.description = 'This gem provides a daemon that handles authorization and reporting of web services managed by 3scale.'
  s.license     = 'Apache-2.0'
  s.metadata    = { 'source_code_uri' => 'https://github.com/3scale/apisonator' }

  s.required_ruby_version     = ">= 3.0"
  s.required_rubygems_version = ">= 1.3.7"

  s.files = Dir.glob('{lib,bin,app,config}/**/*')
  s.files << 'README.md'
  s.files << 'CHANGELOG.md'
  s.files << 'Rakefile'
  s.files << 'config.ru'
  # Gemfile* and gemspec are included here to support
  # running Bundler at gem install time.
  s.files << 'Gemfile'
  s.files << 'Gemfile.lock'
  s.files << 'licenses.xml'
  # License
  s.files << 'LICENSE'
  s.files << 'NOTICE'
  s.files << __FILE__

  s.executables  = ['3scale_backend', '3scale_backend_worker']
  s.require_path = 'lib'

  s.extensions = 'ext/mkrf_conf.rb'
end
