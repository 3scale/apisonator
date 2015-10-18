require 'pathname'

module ThreeScale
  module Backend
    module Util
      def self.number_of_cpus
        cpuinfo_file = '/proc/cpuinfo'.freeze
        if File.readable? cpuinfo_file
          File.open(cpuinfo_file) { |f| f.grep(/\Aprocessor\s*:\s*\d+\Z/).size }
        else
          1 # non-Linux users get a default good enough for dev & test
        end
      end

      def self.root_dir
        File.expand_path(File.join(Array.new(4, '..'.freeze)),
                         Pathname.new(__FILE__).realpath)
      end
    end
  end
end
