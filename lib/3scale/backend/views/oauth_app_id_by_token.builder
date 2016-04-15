xml.instruct!
xml.application do
  xml.app_id @token_to_app_id
end
if @token_to_user_id
  xml.user do
    xml.user_id @token_to_user_id
  end
end
