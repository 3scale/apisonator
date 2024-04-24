resource 'Events' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  let(:first_traffic_event) { { foo: 'bar' } }
  let(:alert_event) { { utilization: 'foo' } }

  get '/events/' do
    context 'when there are no events' do
      example_request 'Getting events' do
        expect(response_status).to eq(200)
        expect(response_json['events']).to eq([])
      end
    end

    context 'when there are events' do
      before do
        ThreeScale::Backend::EventStorage.store(:first_traffic, first_traffic_event)
        ThreeScale::Backend::EventStorage.store(:alert, alert_event)
      end

      example 'Getting events', document: false do
        do_request

        expect(response_status).to eq(200)
        expect(response_json['events'].size).to eq(2)
        expect(response_json['events'].first['type']).to eq('first_traffic')
        expect(response_json['events'].first['object']).to eq(first_traffic_event.stringify_keys)
        expect(response_json['events'].last['type']).to eq('alert')
        expect(response_json['events'].last['object']).to eq(alert_event.stringify_keys)
      end
    end
  end

  delete '/events/:id' do
    parameter :id, "Event ID", required: true

    before do
      ThreeScale::Backend::EventStorage.store(:first_traffic, first_traffic_event)
    end

    context 'when the event exists' do
      let(:id) { ThreeScale::Backend::EventStorage.list.first[:id] }

      example_request "Delete Event by ID" do
        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
      end
    end

    context 'when the event doesn\'t exist' do
      let(:id) { 0 }

      example "Delete Event by ID", document: false do
        do_request

        expect(response_status).to eq(404)
        expect(response_json['status']).to eq('not_found')
      end
    end
  end

  delete '/events/' do
    parameter :upto_id, "ID of the last event of the range", required: true

    context 'when there are errors to delete' do
      before do
        4.times do
          ThreeScale::Backend::EventStorage.store(:first_traffic, first_traffic_event)
        end
      end

      let(:upto_id) { ThreeScale::Backend::EventStorage.list.last[:id] }
      example_request "Delete events by Range" do

        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
        expect(response_json['num_events']).to eq(4)
      end

      example "Delete a subset of events by Range", document: false do
        do_request(upto_id: ThreeScale::Backend::EventStorage.list[1][:id], parameters: { foo: :bar })

        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
        expect(response_json['num_events']).to eq(2)
      end
    end

    context 'when there are no errors to delete' do
      let(:upto_id) { 0 }

      example_request "Delete Events by Range" do
        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
        expect(response_json['num_events']).to eq(0)
      end
    end
  end

  post '/events/' do
    parameter :events, 'Events', required: false

    let(:raw_post) { params.to_json }
    let(:current_last_event_id) do
      if ThreeScale::Backend::EventStorage.list.last
        ThreeScale::Backend::EventStorage.list.last[:id]
      else
        nil
      end
    end
    let(:example_events) do
      [{ type: :first_traffic, object: first_traffic_event },
       { type: :alert, object: alert_event }]
    end

    before do
      if current_last_event_id
        ThreeScale::Backend::EventStorage.delete(current_last_event_id)
      end
    end

    context 'when some events are sent' do
      example 'Save events' do
        do_request(events: example_events)
        events = ThreeScale::Backend::EventStorage.list

        expect(events.size).to eq(example_events.size)

        expect(events[0][:type]).to eq(example_events[0][:type].to_s)
        expect(events[0][:object]).to eq(example_events[0][:object])
        expect(events[1][:type]).to eq(example_events[1][:type].to_s)
        expect(events[1][:object]).to eq(example_events[1][:object])

        expect(response_status).to eq(201)
      end
    end

    context 'when no events are sent' do
      example_request 'Try to save events' do
        expect(response_status).to eq(400)
      end
    end
  end
end
