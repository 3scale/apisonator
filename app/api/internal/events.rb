module ThreeScale
  module Backend
    module API
      internal_api '/events' do
        get '/' do
          { status: :found, events: EventStorage.list }.to_json
        end

        delete '/:id' do
          result = EventStorage.delete(params[:id])
          if result > 0
            { status: :deleted }.to_json
          else
            [404, headers, { status: :not_found, error: 'event not found' }.to_json]
          end
        end

        delete '/' do
          result = EventStorage.delete_range(params[:to_id])
          { status: :deleted, num_events: result }.to_json
        end
      end
    end
  end
end
