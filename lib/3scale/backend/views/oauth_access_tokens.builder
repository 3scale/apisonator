xml.instruct!
xml.oauth_access_tokens do
  @tokens.each do |t|
    # Some bright head leaked the -1 that Redis uses to indicate there is no TTL
    # associated with a key. The behaviour is inconsistent because somehow we
    # BOTH expect that a token with no TTL does not have a "ttl" attribute in
    # the generated XML and at the same time we expect (in some tests) that such
    # tokens have this field with a -1 value.
    #
    # Just enforce the ttl to be -1 when there is none.
    attrs = { :ttl => t.ttl || -1 }
    attrs[:user_id] = t.user_id if t.user_id
    xml.oauth_access_token t.token, attrs
  end
end
