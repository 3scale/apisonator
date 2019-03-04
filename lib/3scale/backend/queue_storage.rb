module ThreeScale
  module Backend
    class QueueStorage
      def self.connection(env, cfg)
        init_params = { url: cfg.queues && cfg.queues.master_name }
        if %w(development test).include?(env)
          init_params[:default_url] = '127.0.0.1:6379'
        end
        options = Backend::Storage::Helpers.config_with(cfg.queues,
                                                        options: init_params)

        Storage.new(options)
      end
    end
  end
end
