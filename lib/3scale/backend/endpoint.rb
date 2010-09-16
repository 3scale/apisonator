module ThreeScale
  module Backend
    class Endpoint < Sinatra::Base
      disable :logging
      disable :raise_errors
      disable :show_exceptions

      configure :production do
        disable :dump_errors
      end

      set :views, File.dirname(__FILE__) + '/views'
          
      register AllowMethods

      use Rack::RestApiVersioning, :default_version => '2.0'

      before do
        content_type 'application/vnd.3scale-v2.0+xml'
      end

      post '/transactions.xml' do
        Transactor.report(params[:provider_key], params[:transactions])
        empty_response 202
      end
      
      get '/transactions/authorize.xml' do
        authorization = Transactor.authorize(params[:provider_key], params)
        authorization.to_xml
      end

      get '/transactions/errors.xml' do
        @errors = ErrorStorage.list(service_id, :page     => params[:page],
                                                :per_page => params[:per_page])

        builder :transaction_errors
      end
      
      delete '/transactions/errors.xml' do
        ErrorStorage.delete_all(service_id)
        empty_response
      end

      get '/transactions/errors/count.xml' do
        @count = ErrorStorage.count(service_id)

        builder :transaction_error_count
      end

      get '/transactions/latest.xml' do
        @transactions = TransactionStorage.list(service_id)

        builder :latest_transactions
      end

      get '/applications/:app_id/constraints/keys.xml' do
        @keys = application.keys

        builder :application_keys
      end
      
      post '/applications/:app_id/constraints/keys.xml' do
        @key = application.create_key

        headers 'Location' => application_constraint_url(application, :keys, @key)
        status 201
        builder :create_application_key
      end

      delete '/applications/:app_id/constraints/keys/:key.xml' do
        application.delete_key(params[:key])
        empty_response
      end

      get '/applications/:app_id/constraints/domains.xml' do
        @domain_constraints = application.domain_constraints

        builder :application_domain_constraints
      end
      
      post '/applications/:app_id/constraints/domains.xml' do
        @domain_constraint = application.create_domain_constraint(params[:domain_constraint])

        headers 'Location' => application_constraint_url(application, :domains, @domain_constraint)
        status 201
        builder :create_application_domain_constraint
      end

      get '/check.txt' do
        content_type 'text/plain'
      end

      error do
        case exception = env['sinatra.error']
        when ThreeScale::Backend::NotFound
          error 404, exception.to_xml
        when ThreeScale::Backend::Error
          error 403, exception.to_xml
        else
          raise exception
        end
      end

      error Sinatra::NotFound do
        error 404, ""
      end
      
      private

      def application
        @application ||= Application.load!(service_id, params[:app_id])
      end

      def service_id
        @service_id ||= Service.load_id!(params[:provider_key])
      end

      def application_constraint_url(application, type, value)
        url("/applications/#{application.id}/constraints/#{type}/#{value}.xml")
      end

      def url(path)
        protocol = request.env['HTTPS'] == 'on' ? 'https' : 'http'
        server   = request.env['SERVER_NAME']

        url = "#{protocol}://#{server}#{path}"
        url += "?provider_key=#{params[:provider_key]}" if params[:provider_key]
        url
      end

      def empty_response(code = 200)
        status code
        body nil
      end
    end
  end
end
