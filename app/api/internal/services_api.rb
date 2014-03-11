module ThreeScale
  module Backend
    module API
      module InternalAPI
        module ServicesAPI
          def self.registered(app)

            app.get '/foo' do
              'bar!'
            end
          end
        end
      end
    end
  end
end
