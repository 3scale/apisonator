require '3scale/backend/util'
require '3scale/backend/opentelemetry'

module ThreeScale
  module Backend
    module Server
      def self.get(server_name)
        server_file = server_name.tr('-', '_')
        require "3scale/backend/server/#{server_file}"
        server_class_name = server_file.tr('_', '').capitalize
        ThreeScale::Backend::Server.const_get server_class_name
      end

      def self.list
        Dir[File.join(ThreeScale::Backend::Util.root_dir, 'lib', '3scale', 'backend', 'server', '*.rb')].map do |s|
          File.basename(s)[0..-4]
        end
      end

      module Utils
        def argv_add(argv, option, switch, *arguments)
          if option
            argv << switch
            arguments.each { |a| argv << a }
          end
          argv
        end
      end
    end
  end
end
