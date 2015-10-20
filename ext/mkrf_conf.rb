# This extension is a hack to allow gem install to take Gemfile into account.
#
require 'rubygems'
require 'rubygems/command.rb'
require 'rubygems/dependency_installer.rb'
require 'pathname'

BUNDLER_REQUIREMENTS = ['~> 1.10.6']

begin
  Gem::Command.build_args = ARGV
rescue NoMethodError
end

begin
  extdir = Pathname.new(__FILE__).dirname.realpath
  rootdir = File.expand_path('..', extdir)
  bundler = begin
              Gem::Specification.find_by_name('bundler', *BUNDLER_REQUIREMENTS)
            rescue Gem::LoadError
              inst = Gem::DependencyInstaller.new
              inst.install('bundler', *BUNDLER_REQUIREMENTS).find do |gs|
                gs.name == 'bundler'
              end
            end
  bundler_version = bundler.version
  bundle_bin = bundler.bin_file 'bundle'
  IO.popen(%W{#{Gem.ruby} #{bundle_bin} install --without development test --gemfile=#{File.join rootdir, 'Gemfile'}}) do |io|
    STDOUT.puts "Running bundler #{bundler_version} at #{bundle_bin} from #{Dir.pwd} with pid #{io.pid}"
    io.each_line { |l| puts l }
  end
  raise "bundle install failed: #{$?.inspect}" unless $?.success?
  # create dummy rakefile to indicate success
  File.open(File.join(extdir, 'Rakefile'), 'w') do |f|
    f.write("task :default\n")
  end
rescue => e
  STDERR.puts "Error: #{e.message} - #{e.class}"
  exit 1
end
