module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/errors' do
        get '/' do |service_id|
          if params[:per_page] && params[:per_page].to_i <= 0
            halt(400, { error: 'per_page needs to be > 0' }.to_json)
          end

          errors = ErrorStorage.list(service_id, page: params[:page],
                                     per_page: params[:per_page])

          # If errors is empty it can mean 2 things:
          # 1) There is not a service with the specified ID.
          # 2) The service exists but has no errors.
          # In the first case we want to return a 404 error.
          if errors.empty? && !Service.load_by_id(service_id)
            [404, headers, { status: :not_found,
                             error: 'service not found' }.to_json]
          else
            errors.each { |error| error[:timestamp] = error[:timestamp].to_s }
            { status: :found, errors: errors,
              count: ErrorStorage.count(service_id) }.to_json
          end
        end

        delete '/' do |service_id|
          if !Service.load_by_id(service_id)
            respond_with_404('service not found')
          else
            ErrorStorage.delete_all(service_id)
            { status: :deleted }.to_json
          end
        end
      end
    end
  end
end
