module ThreeScale
  module Backend
    class QueueStorage
      def self.connection(env, cfg)
        init_params = {}
        if !%w(development test).include?(env)
          raise 'Configuration must have a valid queues section' unless valid_cfg? cfg
          init_params[:url] = cfg.queues.master_name
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
