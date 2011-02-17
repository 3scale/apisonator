module ThreeScale
  module Backend
    module Validators
      autoload :Base,            '3scale/backend/validators/base'
      autoload :OauthSetting,    '3scale/backend/validators/oauth_setting'
      autoload :Key,             '3scale/backend/validators/key'
      autoload :OauthKey,        '3scale/backend/validators/oauth_key'
      autoload :Limits,          '3scale/backend/validators/limits'
      autoload :RedirectUrl,     '3scale/backend/validators/redirect_url'
      autoload :Referrer,        '3scale/backend/validators/referrer'
      autoload :ReferrerFilters, '3scale/backend/validators/referrer_filters'
      autoload :State,           '3scale/backend/validators/state'
    end
  end
end
