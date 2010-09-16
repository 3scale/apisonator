xml.instruct!
xml.domain_constraints do
  @domain_constraints.sort.each do |item|
    xml.domain_constraint :value => item, 
                          :href  => application_constraint_url(application, :domains, item)
  end
end
