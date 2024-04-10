require '3scale/backend/environment'
require '3scale/backend/configuration'
require '3scale/backend/logging/logger'
require '3scale/backend/logging/external'

module ThreeScale
  module Backend
    # include this module to have a handy access to the default logger
    module Logging
      def self.included(base)
        enable! on: base
      end

      def self.enable!(on:, as: :logger, with_args: [], with_opts: {})
        logger = if with_args.empty? && with_opts.empty?
                   Backend.logger
                 else
                   Backend::Logging::Logger.new(*with_args, **with_opts)
                 end

        # define the method before yielding
        on.send :define_method, as do
          logger
        end

        yield logger if block_given?
      end
    end

    class << self

      private

      def enable_logging
        Logging.enable! on: self.singleton_class,
          with_args: [configuration.log_file, 10] do |logger|
          logger.define_singleton_method(:notify, logger_notify_proc(logger))
        end
      end

      def logger_notify_proc(logger)
        external_notify_proc = Logging::External.notify_proc
        proc do |exception, *args, &block|
          logger.error('Exception') { {exception: {class: exception.class, message: exception.message, backtrace: exception.backtrace[0..3]}} }
          external_notify_proc&.call(exception, *args, &block)
        end
      end
    end

    enable_logging
  end
end
