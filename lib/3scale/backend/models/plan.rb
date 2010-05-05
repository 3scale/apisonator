module ThreeScale
  module Backend
    class Plan < ActiveRecord::Base
      belongs_to :service
    end
  end
end
