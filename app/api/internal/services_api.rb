module ThreeScale
  module Backend
    class ServicesAPI < InternalAPI

      get '/foo' do
        'bar!'
      end
    end
  end
end
