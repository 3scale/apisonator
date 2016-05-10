require 'redis'

module ThreeScale
  module Backend
    class QueueStorage
      def self.connection(env, configuration)
        if %w(development test).include?(env)
          Redis.new
        else
          if valid_configuration?(configuration)
            init_params = { url: "redis://#{configuration.queues.master_name}" }
            sentinels = configuration.queues.sentinels
            init_params[:sentinels] = sentinels unless sentinels.empty?
            Redis.new(init_params)
          else
            raise "Configuration must have a valid queues section."
          end
        end
      end

      private

      def self.valid_configuration?(config)
        config.queues && config.queues.master_name && config.queues.sentinels
      end
    end
  end
end
