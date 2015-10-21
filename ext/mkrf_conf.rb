# This extension is a hack to allow gem install to take Gemfile into account.
#
require 'rubygems'
require 'pathname'

BUNDLER_GEM = 'bundler'
BUNDLER_REQUIREMENTS = ['~> 1.10.6']

def gem_install_bundler
  require 'rubygems/command'
  require 'rubygems/commands/install_command'
  begin
    Gem::Command.build_args = ARGV
  rescue NoMethodError
  end

  instcmd = Gem::Commands::InstallCommand.new
  instcmd.handle_options ['-N', BUNDLER_GEM, '--version', *BUNDLER_REQUIREMENTS]
  begin
    instcmd.execute
  rescue Gem::SystemExitException => e
    raise e unless e.exit_code.zero?
  end
end

def get_bundler
  Gem::Specification.find_by_name(BUNDLER_GEM, *BUNDLER_REQUIREMENTS)
end

begin
  extdir = Pathname.new(__FILE__).dirname.realpath
  rootdir = File.expand_path('..', extdir)
  gem_install_bundler
  bundler = get_bundler
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
