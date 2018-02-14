module ThreeScale
  module Backend
    module Logging
      module External
        # This is the module that each implementation has to populate with its
        # own class. The implementation file must be named after the class and
        # live in a specific subdirectory relative to this file matching this
        # file's name.
        #
        # To load the class one must specify a symbol with the base name without
        # extension as the file that implements it. The class name is expected
        # to be the capitalized symbol.
        module Impl
          # methods to be implemented by each external logging service
          #
          # setup - Meant to configure the service for a general use. Each other
          #         method in the list calls setup if it has not been called
          #         before.
          # setup_rake - Perform additional configuration for Rake
          # setup_rack - Receives the Rack object, meant to add a middleware.
          # setup_worker - Additional configuration for job worker usage.
          # notify_proc - The global logger's notify method will call the proc
          #               returned by this. If nil is returned a fallback will
          #               be chosen for that method (typically local logging).
          #
          METHODS = [:setup, :setup_rake, :setup_rack,
                     :setup_worker, :notify_proc].freeze

          class Error < StandardError
            class FileNotFound < self
              def initialize(impl)
                super "external logging implementation not found for #{impl.inspect}"
              end
            end

            class ClassNotFound < self
              def initialize(impl)
                super "external logging implementation does not provide a " \
                  "similarly named class: #{impl.inspect}"
              end
            end
          end

          class << self
            # returns the class implementing the logging service
            def load(impl)
              require(find_file impl)

              fetch_impl_klass impl
            end

            private

            def find_file(impl)
              re = build_regexp impl

              impl_file = Dir[glob].find do |path|
                re.match(File.basename path)
              end

              impl_file || raise(Error::FileNotFound.new(impl))
            end

            def fetch_impl_klass(impl)
              const_get(impl.capitalize)
            rescue NameError
              raise Error::ClassNotFound.new(impl)
            end

            def build_regexp(impl)
              Regexp.new("\\A#{Regexp.escape(impl.to_s + extname)}\\z")
            end

            # these are almost constants, but since this is meant to be init
            # code with throw-away strings they are left here as helper methods
            def glob
              directory << File::SEPARATOR << '*' << File.extname(__FILE__)
            end

            def directory
              __FILE__.chomp(extname) + File::SEPARATOR
            end

            def extname
              # assume implementations will be coded in our own language
              File.extname __FILE__
            end
          end
        end
      end
    end
  end
end
