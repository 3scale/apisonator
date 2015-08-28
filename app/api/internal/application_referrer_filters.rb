require 'base64'

module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/applications/:app_id/referrer_filters' do
        before do
          @app = Application.load params[:service_id], params[:app_id]
          respond_with_404 'application not found'  unless @app
        end

        get '' do
          filters = @app.referrer_filters.sort
          {status: :found, referrer_filters: filters}.to_json
        end

        post '' do
          begin
            value = params.fetch(:referrer_filter, nil)
            filter = @app.create_referrer_filter(value)

            [201, headers, {status: :created, referrer_filter: filter}.to_json]
          rescue ReferrerFilterInvalid => e
            respond_with_400 e
          end
        end

        delete '/:value' do
          filter = begin
            Base64.urlsafe_decode64 params[:value]
          rescue ArgumentError
            params[:value]
          end
          @app.delete_referrer_filter filter

          {status: :deleted}.to_json
        end

      end
    end
  end
end

