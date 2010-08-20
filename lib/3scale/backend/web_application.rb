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
        authorization = Transactor.authorize(params['provider_key'],
                                             params['app_id'],
                                             params['app_key'])
        
        status 200

        body authorization.to_xml
      end

      error do
        error 403, env['sinatra.error'].to_xml
      end
    end
  end
end
