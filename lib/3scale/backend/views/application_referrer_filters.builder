xml.instruct!
xml.referrer_filters do
  @referrer_filters.sort.each do |item|
    xml.referrer_filter :value => item, 
                        :href  => application_resource_url(application, :referrer_filters, item)
  end
end
