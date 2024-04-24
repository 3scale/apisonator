require 'timecop'

resource 'Errors (prefix: /services/:service_id/errors)' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  let(:service_id) { '7575' }
  let(:service_id_non_existent) { service_id.to_i.succ.to_s }

  before do
    ThreeScale::Backend::Service.save!(provider_key: 'foo', id: service_id)
    ThreeScale::Backend::ErrorStorage.delete_all(service_id)
  end

  get '/services/:service_id/errors/' do
    parameter :service_id, 'Service ID', required: true

    context 'when there are no errors' do
      example_request 'Get errors by service ID' do
        expect(response_json['errors']).to be_empty
        expect(response_json['count']).to be_zero
        expect(response_status).to eq(200)
      end
    end

    context 'when there are errors but do not care about pagination' do
      let(:test_time) { Time.utc(2010, 9, 3, 17, 9) }

      before do
        Timecop.freeze(test_time) do
          ThreeScale::Backend::ErrorStorage.store(
              service_id, ThreeScale::Backend::ApplicationNotFound.new('boo'))
        end
      end

      example_request 'Get errors by service ID' do
        error = response_json['errors'].first
        expect(error['code']).to eq ('application_not_found')
        expect(error['message']).to eq('application with id="boo" was not found')
        expect(error['timestamp']).to eq(test_time.to_s)
        expect(response_json['count']).to eq(1)
        expect(response_status).to eq(200)
      end

      example 'Try with invalid service ID' do
        do_request(service_id: service_id_non_existent)
        expect(response_status).to eq(404)
      end
    end

    context 'when there are multiple errors and want to use pagination' do
      let(:provider_key_invalid_errors) { ThreeScale::Backend::ErrorStorage::PER_PAGE }
      let(:metric_invalid_errors) { 2 }
      let(:usage_value_invalid_errors) { 3 }
      let(:application_not_found_errors) { usage_value_invalid_errors }
      let(:errors_per_page) { usage_value_invalid_errors }

      let(:test_errors) do
        errors = Array.new(provider_key_invalid_errors) do
          ThreeScale::Backend::ProviderKeyInvalid.new('test_app')
        end
        metric_invalid_errors.times do
          errors << ThreeScale::Backend::MetricInvalid.new('foo')
        end
        usage_value_invalid_errors.times do
          errors << ThreeScale::Backend::UsageValueInvalid.new('hits', 'lots')
        end
        application_not_found_errors.times do
          errors << ThreeScale::Backend::ApplicationNotFound.new('boo')
        end
        errors
      end

      before do
        test_errors.each do |error|
          ThreeScale::Backend::ErrorStorage.store(service_id, error)
        end
      end

      example_request 'Get errors without specifying page nor errors per page' do
        expect(response_json['errors'].size).to eq(ThreeScale::Backend::ErrorStorage::PER_PAGE)
        expect(response_json['count']).to eq(test_errors.size)
        expect(response_status).to eq(200)
      end

      example 'Get errors of page #1' do
        do_request(page: 1, per_page: errors_per_page)
        expect(response_json['errors'].first['code']).to eq('application_not_found')
        expect(response_json['errors'].size).to eq(errors_per_page)
        expect(response_json['count']).to eq(test_errors.size)
        expect(response_status).to eq(200)
      end

      example 'Get errors of page #2' do
        do_request(page: 2, per_page: errors_per_page)
        expect(response_json['errors'].first['code']).to eq('usage_value_invalid')
        expect(response_json['errors'].size).to eq(errors_per_page)
        expect(response_json['count']).to eq(test_errors.size)
        expect(response_status).to eq(200)
      end

      example 'Get errors of page #3' do
        do_request(page: 3, per_page: errors_per_page)
        expect(response_json['errors'].first['code']).to eq('metric_invalid')
        expect(response_json['errors'].size).to eq(errors_per_page)
        expect(response_json['count']).to eq(test_errors.size)
        expect(response_status).to eq(200)
      end

      example 'Try specifying page with no elements' do
        do_request(page: 2, per_page: test_errors.size + 1)
        expect(response_json['errors']).to be_empty
        expect(response_json['count']).to eq(test_errors.size)
        expect(response_status).to eq(200)
      end

      example 'Try with last page having just one error' do
        do_request(page: 2, per_page: test_errors.size - 1)
        expect(response_json['errors'].first['code']).to eq('provider_key_invalid')
        expect(response_json['errors'].size).to eq(1)
        expect(response_json['count']).to eq(test_errors.size)
      end

      example 'Try with negative per_page value' do
        do_request(page: 1, per_page: -1)
        expect(response_status).to eq(400)
      end
    end
  end

  delete '/services/:service_id/errors/' do
    parameter :service_id, 'Service ID', required: true

    context 'when there are no errors' do
      example_request 'Delete all errors' do
        expect(response_status).to eq(200)
        expect(ThreeScale::Backend::ErrorStorage.list(service_id)).to be_empty
      end
    end

    context 'when there are errors' do
      before do
        3.times { ThreeScale::Backend::ErrorStorage.store(
            service_id, ThreeScale::Backend::ApplicationNotFound.new('boo')) }
      end

      example_request 'Delete all errors' do
        expect(response_status).to eq(200)
        expect(ThreeScale::Backend::ErrorStorage.list(service_id)).to be_empty
      end

      example 'Try with invalid service ID' do
        do_request(service_id: service_id_non_existent)
        expect(response_status).to eq(404)
        expect(ThreeScale::Backend::ErrorStorage.list(service_id_non_existent)).to be_empty
      end
    end
  end

  post '/services/:service_id/errors/' do
    parameter :service_id, 'Service ID', required: true
    parameter :errors, 'Errors', required: false

    let(:example_error_messages) do
      %w(error_msg_#1 error_msg_#2 error_msg_#3)
    end

    define_method :raw_post do
      params.to_json
    end

    context 'when the service exists' do
      example 'Save errors' do
        do_request(service_id: service_id, errors: example_error_messages)

        saved_errors = ThreeScale::Backend::ErrorStorage.list(service_id)
        expect(saved_errors.map { |error| error[:message] })
            .to eq example_error_messages.reverse

        expect(response_status).to eq(201)
      end

      example 'Try without specifying errors' do
        do_request(service_id: service_id)
        expect(response_status).to eq(400)
      end
    end

    context 'when the service does not exist' do
      example 'Try to save errors' do
        do_request(service_id: service_id_non_existent,
                   errors: example_error_messages)
        expect(response_status).to eq(404)
      end
    end
  end
end
