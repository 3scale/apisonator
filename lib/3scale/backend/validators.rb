module ThreeScale
  module Backend
    module Validators
      autoload :Base,   '3scale/backend/validators/base'
      autoload :Domain, '3scale/backend/validators/domain'
      autoload :Key,    '3scale/backend/validators/key'
      autoload :Limits, '3scale/backend/validators/limits'
      autoload :State,  '3scale/backend/validators/state'
    end
  end
end
