module ThreeScale
  module Backend
    class WebApplication < Sinatra::Base
      set :environment, :production

      before do
        content_type 'application/vnd.3scale-v1.1+xml'
      end

      get '/check.txt' do
        content_type 'text/plain'
        status 200
      end

      post '/transactions.xml' do
        Transactor.report(params[:provider_key], params[:transactions])

        status 200
      end
      
      get '/transactions/authorize.xml' do
        authorization = Transactor.authorize(params[:provider_key],
                                             params[:app_id],
                                             params[:app_key])
        
        status 200
        body authorization.to_xml
      end

      get '/applications/:app_id/keys' do
        service_id  = Service.load_id!(params[:provider_key])
        application = Application.load!(service_id, params[:app_id])

        status 200
      end

      error do
        exception = env['sinatra.error']

        if exception.is_a?(ThreeScale::Backend::Error)
          error 403, exception.to_xml
        else
          raise exception
        end
      end

      private

      def authorize_and_notify(methods = {})
        Transactor.authorize_and_notify(params[:provider_key], methods)
      end
    end
  end
end
