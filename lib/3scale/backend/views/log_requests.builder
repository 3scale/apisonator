xml.instruct!
xml.log_requests do
  @list.each do |item|
    timestamp = item[:timestamp].nil? ? '' : item[:timestamp].strftime(ThreeScale::TIME_FORMAT)

    xml.log_request do
      xml.service_id  item[:service_id]
      xml.app_id  item[:application_id]
      xml.user_id item[:user_id] unless item[:user_id].nil?
      xml.usage item[:usage] unless item[:usage].nil?
      xml.timestamp timestamp
      xml.request item[:log]['request']
      xml.response item[:log]['response']
      xml.code item[:log]['code']
    end
  end
end
