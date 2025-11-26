module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/applications' do
        # Helper method to save a single application with all its associated data
        def save_application_with_data(service_id, app_data)
          app_id = app_data[:id]
          app_attrs = valid_request_attrs(app_data, Application.attribute_names)
          app_attrs[:service_id] = service_id
          app_attrs[:id] = app_id

          app = Application.save(app_attrs)

          if app_data[:user_key]
            Application.save_id_by_key(service_id, app_data[:user_key], app_id)
          end

          if app_data[:application_keys]
            app_data[:application_keys].each do |key|
              app.create_key(key)
            end
          end

          if app_data[:referrer_filters]
            app_data[:referrer_filters].each do |filter|
              app.create_referrer_filter(filter)
            end
          end

          app
        end

        put '/batch' do |service_id|
          batch_data = params[:applications]
          halt 400, { status: :error, error: "missing parameter 'applications'" }.to_json unless batch_data

          total = batch_data.size
          successful = 0
          failed = 0
          applications = []
          failures = []

          batch_data.each do |app_data|
            app_id = app_data[:id]
            app_existed = Application.exists?(service_id, app_id)

            begin
              app = save_application_with_data(service_id, app_data)

              # This is the fastest way to know whether the user key is properly synced
              user_key_persisted = Application.load_id_by_key(service_id, app_data[:user_key]) == app.id
              user_key = user_key_persisted ? app_data[:user_key] : nil

              result = {
                status: app_existed ? :modified : :created,
                application: app.to_hash.merge(
                  user_key: user_key,
                  application_keys: app.keys,
                  referrer_filters: app.referrer_filters
                )
              }
              applications << result
              successful += 1
            rescue => e
              applications << { status: :error, id: app_id, error: e.message }
              failures << { id: app_id, error: e.message }
              failed += 1
            end
          end

          response = {
            status: :completed,
            total: total,
            successful: successful,
            failed: failed,
            applications: applications
          }
          response[:failures] = failures if failures.any?

          response.to_json
        end

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
