module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/errors' do
        before do
          unless Service.exists?(params[:service_id])
            respond_with_404('service not found')
          end
        end

        get '/' do |service_id|
          if params[:per_page] && params[:per_page].to_i <= 0
            halt(400, { error: 'per_page needs to be > 0' }.to_json)
          end

          errors = ErrorStorage.list(service_id,
                                     page: params[:page],
                                     per_page: params[:per_page])
          errors.each { |error| error[:timestamp] = error[:timestamp].to_s }
          { status: :found, errors: errors,
            count: ErrorStorage.count(service_id) }.to_json
        end

        delete '/' do |service_id|
          ErrorStorage.delete_all(service_id)
          { status: :deleted }.to_json
        end

        if define_private_endpoints?
          # Receives a parameter 'errors' which is an Array of Strings
          # representing error messages.
          # In this endpoint, we create errors of the generic type Error to
          # keep things simple because we do not care about the type.
          # If this changes in the future we might need to create errors
          # of other types such as: ProviderKeyInvalid, KeyInvalid...
          post '/' do |service_id|
            errors = params[:errors]

            unless errors
              halt 400, { status: :error,
                          error: 'missing parameter \'errors\'' }.to_json
            end

            errors.each do |error|
              ErrorStorage.store(service_id, Error.new(error))
            end

            [201, headers, { status: :created }.to_json]
          end
        end
      end
    end
  end
end
