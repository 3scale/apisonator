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

      # OIDC specific validators will only check app keys when app_key is given.
      #
      # No need to add OauthSetting, since we need to check that to tell
      # OIDC apart from the rest when calling authrep.xml (note lack of
      # the oauth_ prefix).
      OIDC_VALIDATORS = ([Validators::OauthKey] + COMMON_VALIDATORS).freeze
    end
  end
end
