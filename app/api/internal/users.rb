module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/users' do
        module UserHelper
          def self.save(service_id, username, usr_attrs, method, headers)
            usr_attrs[:service_id] = service_id
            usr_attrs[:username] = username
            begin
              user = User.save! usr_attrs
            rescue => e
              [400, headers, { status: :error, error: e.message }.to_json]
            else
              post = method == :post
              [post ? 201 : 200, headers, { status: post ? :created : :modified, user: user.to_hash }.to_json]
            end
          end
        end

        get '/:username' do |service_id, username|
          user = User.load(service_id, username)
          if user
            { status: :found, user: user.to_hash }.to_json
          else
            [404, headers, { status: :not_found, error: 'user not found' }.to_json]
          end
        end

        post '/:username' do |service_id, username|
          user_attrs = api_params User
          UserHelper.save(service_id, username, user_attrs, :post, headers)
        end

        put '/:username' do |service_id, username|
          user_attrs = api_params User
          UserHelper.save(service_id, username, user_attrs, :put, headers)
        end

        delete '/:username' do |service_id, username|
          begin
            User.delete! service_id, username
            { status: :deleted }.to_json
          rescue => e
            [400, headers, { status: :error, error: e.message }.to_json]
          end
        end
      end
    end
  end
end
