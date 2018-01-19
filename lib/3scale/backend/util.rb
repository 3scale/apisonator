require 'pathname'
require 'etc'

module ThreeScale
  module Backend
    module Util
      def self.number_of_cpus
        Etc.nprocessors
      end

      def self.root_dir
        File.expand_path(File.join(Array.new(4, '..'.freeze)),
                         Pathname.new(__FILE__).realpath)
      end
    end
  end
end
