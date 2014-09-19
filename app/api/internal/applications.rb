module ThreeScale
  module Backend
    module API
      class Applications < Internal

        get '/:service_id/applications/:id' do
          app = Application.load(params[:service_id], params[:id])
          if app
            { status: :found, application: app.to_hash }.to_json
          else
            [404, headers, { status: :not_found, error: 'application not found' }.to_json]
          end
        end

        post '/:service_id/applications/:id' do
          attributes = params[:application]
          halt 400, { status: :error, error: 'invalid parameter \'application\'' }.to_json unless attributes
          service_id, id = params[:service_id], params[:id]
          if Application.exists?(service_id, id)
            halt 405, { status: :exists, error: 'application cannot be created, exists already' }.to_json
          end
          attributes.merge!({service_id: service_id, id: id})
          app = Application.save(attributes)
          [201, headers, { status: :created, application: app.to_hash }.to_json]
        end

        put '/:service_id/applications/:id' do
          attributes = params[:application]
          halt 400, { status: :error, error: 'invalid parameter \'application\'' }.to_json unless attributes
          app = Application.load(params[:service_id], params[:id])
          if app
            app.update(attributes).save
            { status: :modified, application: app.to_hash }.to_json
          else
            [404, headers, { status: :not_found, error: 'application not found' }.to_json]
          end
        end

        delete '/:service_id/applications/:id' do
          attributes = params[:application]
          halt 400, { status: :error, error: 'invalid parameter \'application\'' }.to_json unless attributes
          begin
            Application.delete(params[:service_id], params[:id])
            { status: :deleted }.to_json
          rescue ApplicationNotFound
            [404, headers, { status: :not_found, error: 'application not found' }.to_json]
          end
        end
      end
    end
  end
end
