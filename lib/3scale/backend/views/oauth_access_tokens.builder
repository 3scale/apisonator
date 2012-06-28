xml.instruct!
xml.oauth_access_tokens do
  @tokens.each do |t|
    attrs = t.ttl ? { :ttl => t.ttl } : {}
    xml.oauth_access_token t.token, attrs
  end
end
