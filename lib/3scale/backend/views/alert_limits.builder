xml.instruct!
xml.alert_limits do
  @list.each do |item|
    xml.limit :value => item
  end
end
