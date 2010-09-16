module ThreeScale
  module Backend
    module Validators
      autoload :Base,            '3scale/backend/validators/base'
      autoload :Key,             '3scale/backend/validators/key'
      autoload :Limits,          '3scale/backend/validators/limits'
      autoload :Referrer,        '3scale/backend/validators/referrer'
      autoload :ReferrerFilters, '3scale/backend/validators/referrer_filters'
      autoload :State,           '3scale/backend/validators/state'
    end
  end
end
