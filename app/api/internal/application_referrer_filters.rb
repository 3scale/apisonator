module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/applications/:app_id/' do
        before do
          @app = Application.load params[:service_id], params[:app_id]
          respond_with_404 "foo"  unless @app
        end

        get 'referrer_filters' do |service_id, id|
          filters = @app.referrer_filters.sort
          {status: :found, referrer_filters: filters}.to_json
        end

      end
    end
  end
end

