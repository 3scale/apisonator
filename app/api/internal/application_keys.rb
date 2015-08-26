module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/applications/:app_id/keys' do
        module ApplicationKeysHelper
          def self.to_hash(app, value)
            {
              service_id: app.service_id,
              app_id:     app.id,
              value:      value,
            }
          end
        end

        before do
          @app = Application.load(params[:service_id], params[:app_id])
          respond_with_404 'application not found' unless @app
        end

        get '/' do |service_id, app_id|
          keys = @app.keys.map do |key|
            ApplicationKeysHelper.to_hash(@app, key)
          end

          { status: :found, application_keys: keys }.to_json
        end

        post '/' do |service_id, app_id|
          value = params.fetch(:application_key, {}).fetch(:value, nil)
          key   = { app_id: @app.id }
          if value.nil? || value.empty?
            key.merge!(value: @app.create_key)
          else
            key.merge!(value: @app.create_key(value))
          end
          [201, headers, { status: :created, application_key: key }.to_json]
        end

        delete '/:id' do |service_id, app_id, id|
          if @app.delete_key(id)
            { status: :deleted }.to_json
          else
            respond_with_404("application key not found")
          end
        end
      end
    end
  end
end
