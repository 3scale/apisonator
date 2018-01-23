module ThreeScale
  module Backend
    class QueueStorage
      def self.connection(env, cfg)
        init_params = {}
        if !%w(development test).include?(env)
          raise 'Configuration must have a valid queues section' if !valid_cfg?(cfg)
          init_params[:url] = cfg.queues.master_name
          sentinels = cfg.queues.sentinels
          init_params[:sentinels] = sentinels unless sentinels.empty?
        else
          init_params[:default_url] = '127.0.0.1:6379'
        end

        options = Backend::Storage::Helpers.config_with(cfg.queues,
                                                        options: init_params)

        Redis.new options
      end

      private

      def self.valid_cfg?(cfg)
        cfg.queues && cfg.queues.master_name && cfg.queues.sentinels
      end
    end
  end
end
