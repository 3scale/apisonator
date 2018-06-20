require '3scale/backend/validators/base'
require '3scale/backend/validators/oauth_setting'
require '3scale/backend/validators/key'
require '3scale/backend/validators/oauth_key'
require '3scale/backend/validators/limits'
require '3scale/backend/validators/redirect_uri'
require '3scale/backend/validators/referrer'
require '3scale/backend/validators/state'
require '3scale/backend/validators/service_state'

module ThreeScale
  module Backend
    module Validators
      COMMON_VALIDATORS = [Validators::Referrer,
                           Validators::State, # application state
                           Validators::ServiceState, # service state
                           Validators::Limits].freeze

      VALIDATORS = ([Validators::Key] + COMMON_VALIDATORS).freeze

      OAUTH_VALIDATORS = ([Validators::OauthSetting,
                           Validators::OauthKey,
                           Validators::RedirectURI] + COMMON_VALIDATORS).freeze
    end
  end
end
