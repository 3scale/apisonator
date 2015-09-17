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
          result = EventStorage.delete_range(params[:upto_id])
          { status: :deleted, num_events: result }.to_json
        end

        if define_private_endpoints?
          post '/' do
            events = params[:events]

            unless events
              halt 400, { status: :error,
                          error: 'missing parameter \'events\'' }.to_json
            end

            events.each do |event|
              EventStorage.store(event[:type].to_sym, event[:object])
            end

            [201, headers, { status: :created }.to_json]
          end
        end
      end
    end
  end
end
