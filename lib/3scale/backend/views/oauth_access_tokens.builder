xml.instruct!
xml.oauth_access_tokens do
  @tokens.each do |t|
    attrs = t.ttl ? { :ttl => t.ttl } : {}
    attrs[:user_id] = t.user_id if t.user_id
    xml.oauth_access_token t.token, attrs
  end
end
