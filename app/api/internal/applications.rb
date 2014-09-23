module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/applications' do
        get '/:id' do |service_id, id|
          app = Application.load(service_id, id)
          if app
            { status: :found, application: app.to_hash }.to_json
          else
            [404, headers, { status: :not_found, error: 'application not found' }.to_json]
          end
        end

        post '/:id' do |service_id, id|
          attributes = params[:application]
          halt 400, { status: :error, error: 'invalid parameter \'application\'' }.to_json unless attributes
          if Application.exists?(service_id, id)
            halt 405, { status: :exists, error: 'application cannot be created, exists already' }.to_json
          end
          attributes.merge!({service_id: service_id, id: id})
          app = Application.save(attributes)
          [201, headers, { status: :created, application: app.to_hash }.to_json]
        end

        put '/:id' do |service_id, id|
          attributes = params[:application]
          halt 400, { status: :error, error: 'invalid parameter \'application\'' }.to_json unless attributes
          app = Application.load(service_id, id)
          if app
            app.update(attributes).save
            { status: :modified, application: app.to_hash }.to_json
          else
            [404, headers, { status: :not_found, error: 'application not found' }.to_json]
          end
        end

        delete '/:id' do |service_id, id|
          begin
            Application.delete(service_id, id)
            { status: :deleted }.to_json
          rescue ApplicationNotFound
            [404, headers, { status: :not_found, error: 'application not found' }.to_json]
          end
        end

      end
    end
  end
end
