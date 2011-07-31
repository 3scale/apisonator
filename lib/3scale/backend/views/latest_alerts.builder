xml.instruct!
xml.alerts do
  @list.each do |item|
    timestamp = item[:timestamp].nil? ? '' : item[:timestamp].strftime(ThreeScale::TIME_FORMAT)

    xml.alert       :id             => item[:id],
                    :service_id     => item[:service_id],
                    :application_id => item[:application_id],
                    :timestamp      => timestamp,
                    :max_utilization    => item[:max_utilization],
                    :utilization    => item[:utilization],
                    :limit          => item[:limit]
    
  end
end
