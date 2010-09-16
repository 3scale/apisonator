xml.instruct!
xml.errors do
  @errors.each do |error|
    xml.error error[:message], :code      => error[:code], 
                               :timestamp => error[:timestamp]
  end
end
