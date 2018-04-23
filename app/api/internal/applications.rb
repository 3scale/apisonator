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
          app_attrs = api_params Application
          if Application.exists?(service_id, id)
            halt 405, { status: :exists, error: 'application cannot be created, exists already' }.to_json
          end
          app_attrs[:service_id] = service_id
          app_attrs[:id] = id
          begin
            app = Application.save(app_attrs)
          rescue ApplicationHasNoState => e
            [400, headers, { status: :bad_request, error: e.message }.to_json]
          else
            [201, headers, { status: :created, application: app.to_hash }.to_json]
          end
        end

        put '/:id' do |service_id, id|
          app_attrs = api_params Application
          modified = Application.exists?(service_id, id)
          app_attrs[:service_id] = service_id
          app_attrs[:id] = id
          begin
            app = Application.save(app_attrs)
          rescue ApplicationHasNoState => e
            [400, headers, { status: :bad_request, error: e.message }.to_json]
          else
            { status: modified ? :modified : :created, application: app.to_hash }.to_json
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

        # XXX Old API. DEPRECATED.
        #
        # We will NOT be loading the whole app for the key requested, which we
        # would probably do otherwise, since users are only marginal, do not
        # need it anyway, and are to be removed in the future.
        #
        get '/key/:user_key' do |service_id, user_key|
          id = Application.load_id_by_key(service_id, user_key)
          halt 404, { status: :not_found, error: 'application key not found' }.to_json unless id
          { status: :found, application: { id: id } }.to_json
        end

        put '/:id/key/:user_key' do |service_id, id, user_key|
          Application.save_id_by_key(service_id, user_key, id)
          { status: :modified, application: { id: id } }.to_json
        end

        delete '/key/:user_key' do |service_id, user_key|
          Application.delete_id_by_key(service_id, user_key)
          { status: :deleted }.to_json
        end
      end
    end
  end
end
