xml.instruct!
xml.oauth_access_tokens do
  @tokens.each do |token|
    xml.oauth_access_token do
      xml.token token.token
      xml.ttl token.ttl
      xml.application_id token.api_id
    end
  end
end
