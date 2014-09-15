module ThreeScale
  module Backend
    module API
      class Applications < Internal

        def self.body_attributes
          [:service_id, :id, :state, :plan_id, :plan_name, :user_required, :redirect_url]
        end

        get '/' do
          filter_body_params params, :application => Hash[[[:service_id, :value], [:id, :value]]]
          attributes = params[:application]
          halt 400, {error: 'invalid parameter \'application\''}.to_json unless attributes
          app = Application.load(attributes[:service_id], attributes[:id])
          if app
            { application: app.to_hash }.to_json
          else
            [404, headers, {status: :not_found, error: 'application not found' }.to_json]
          end
        end

        post '/' do
          filter_body_params params,
                  :application => Hash[Applications.body_attributes.product([:value])]
          attributes = params[:application]
          halt 400, {error: 'invalid parameter \'application\''}.to_json unless attributes
          if Application.exists?(attributes[:service_id], attributes[:id])
            halt 405, {error: 'application cannot be created, exists already'}.to_json
          end
          app = Application.save(attributes)
          [201, headers, {application: app.to_hash, status: :created}.to_json]
        end

        put '/' do
          filter_body_params params,
                  :application => Hash[Applications.body_attributes.product([:value])]
          attributes = params[:application]
          halt 400, {error: 'invalid parameter \'application\''}.to_json unless attributes
          app = Application.load(attributes[:service_id], attributes[:id])
          if app
            app.update(attributes).save
            {application: app.to_hash, status: :ok}.to_json
          else
            [404, headers, {error: :not_found}.to_json]
          end
        end

        delete '/' do
          filter_body_params params, :application => Hash[[[:service_id, :value], [:id, :value]]]
          attributes = params[:application]
          halt 400, {error: 'invalid parameter \'application\''}.to_json unless attributes
          begin
            Application.delete(attributes[:service_id], attributes[:id])
            {status: :ok}.to_json
          rescue ApplicationNotFound => e
            respond_with_404 e
          end
        end
      end
    end
  end
end
