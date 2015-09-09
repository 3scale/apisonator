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

          errors = ErrorStorage.list(service_id, page: params[:page],
                                     per_page: params[:per_page])
          errors.each { |error| error[:timestamp] = error[:timestamp].to_s }
          { status: :found, errors: errors,
            count: ErrorStorage.count(service_id) }.to_json
        end

        delete '/' do |service_id|
          ErrorStorage.delete_all(service_id)
          { status: :deleted }.to_json
        end
      end
    end
  end
end
