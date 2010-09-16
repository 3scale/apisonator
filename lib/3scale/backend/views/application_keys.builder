xml.instruct!
xml.keys do
  @keys.sort.each do |item|
    xml.key :value => item, :href => application_resource_url(application, :keys, item)
  end
end
