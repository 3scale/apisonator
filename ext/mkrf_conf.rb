# This extension is a hack to allow gem install to take Gemfile into account.
#
require 'rubygems'
require 'rubygems/command.rb'
require 'rubygems/dependency_installer.rb'
require 'pathname'

begin
  Gem::Command.build_args = ARGV
rescue NoMethodError
end

begin
  inst = Gem::DependencyInstaller.new
  inst.install 'bundler', '~> 1.10.6'
  extdir = Pathname.new(__FILE__).dirname.realpath
  rootdir = File.expand_path('..', extdir)
  IO.popen(%W{bundle install --without development test --gemfile=#{File.join rootdir, 'Gemfile'}}) do |io|
    STDOUT.puts "Running bundler with pid #{io.pid}"
    io.each_line { |l| puts l }
  end
  raise 'bundle install failed' unless $?.success?
  # create dummy rakefile to indicate success
  File.open(File.join(extdir, 'Rakefile'), 'w') do |f|
    f.write("task :default\n")
  end
rescue => e
  STDERR.puts "Error: #{e.message} - #{e.class}"
  exit 1
end
