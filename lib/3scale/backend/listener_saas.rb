module ThreeScale
  module Backend
    class Listener
      # For now, the only SaaS-specific endpoints are the request logs ones.

      get '/services/:service_id/applications/:app_id/log_requests.xml' do
        @list = LogRequestStorage.list_by_application(service_id, application.id)
        builder :log_requests
      end

      get '/applications/:app_id/log_requests.xml' do
        ## FIXME: two ways of doing the same
        ## get '/services/:service_id/applications/:app_id/log_requests.xml'
        @list = LogRequestStorage.list_by_application(service_id, application.id)
        builder :log_requests
      end

      get '/services/:service_id/log_requests.xml' do
        @list = LogRequestStorage.list_by_service(service_id)
        builder :log_requests
      end

      delete '/services/:service_id/applications/:app_id/log_requests.xml' do
        LogRequestStorage.delete_by_application(service_id, application.id)
        200
      end

      delete '/applications/:app_id/log_requests.xml' do
        ## FIXME: two ways of doing the same
        ## delete '/services/:service_id/applications/:app_id/log_requests.xml'
        LogRequestStorage.delete_by_application(service_id, application.id)
        200
      end

      delete '/services/:service_id/log_requests.xml' do
        LogRequestStorage.delete_by_service(service_id)
        200
      end
    end
  end
end
