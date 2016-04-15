# This module encodes values in Redis for our tokens
#
# The values need to provide both app and user ids, but the latter are optional.
#
module ThreeScale
  module Backend
    module OAuth
      class Token
        module Value
          class << self
            TOKEN_HAS_USER_FIELD = "user_len".freeze
            # for ':' and '/'; the size of the user's len is determined and
            # added in a different place.
            TOKEN_HAS_USER_CONSTSIZE = TOKEN_HAS_USER_FIELD.size + 1 + 1
            TOKEN_HAS_USER_RE = /#{Regexp.escape("#{TOKEN_HAS_USER_FIELD}")}:(?<ulen>\d+)\//
            private_constant  :TOKEN_HAS_USER_FIELD,
              :TOKEN_HAS_USER_CONSTSIZE,
              :TOKEN_HAS_USER_RE

            # this method is used when creating tokens
            def for(app_id, user_id)
              if user_id.nil?
                return app_id if app_id !~ TOKEN_HAS_USER_RE
                # unlikely that an app starts with "user_len:\d+/"... but we can
                # support it by just using user_len:0//user_len:\d+/.
                user_id = ''.freeze
              end
              "#{TOKEN_HAS_USER_FIELD}:#{user_id.size}/#{user_id}/#{app_id}"
            end

            # values have the form "user_len:4/alex/app_id_goes_here"
            def from(value)
              app_id = value
              if app_id
                md = TOKEN_HAS_USER_RE.match value
                if md
                  # we assume no one has added rogue keys that declare bad sizes
                  uidx = TOKEN_HAS_USER_CONSTSIZE + md[:ulen].size
                  ulen = md[:ulen].to_i
                  split_idx = uidx + ulen
                  user_id = value[uidx...split_idx] if ulen > 0
                  app_id = value[split_idx+1..-1]
                end
              else
                user_id = nil
              end
              [app_id, user_id]
            end
          end
        end
      end
    end
  end
end
