require 'redis'

module ThreeScale
  module Backend
    class QueueStorage
      def self.connection(env, cfg)
        init_params = { driver: :hiredis }
        if !%w(development test).include?(env)
          raise 'Configuration must have a valid queues section' if !valid_cfg?(cfg)
          init_params[:url] = "redis://#{cfg.queues.master_name}"
          sentinels = cfg.queues.sentinels
          init_params[:sentinels] = sentinels unless sentinels.empty?
        end
        Redis.new(init_params)
      end

      private

      def self.valid_cfg?(cfg)
        cfg.queues && cfg.queues.master_name && cfg.queues.sentinels
      end
    end
  end
end
