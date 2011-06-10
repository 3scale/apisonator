xml.instruct!
xml.transactions do
  @transactions.each do |transaction|
    timestamp = transaction[:timestamp].nil? ? '' : transaction[:timestamp].strftime(ThreeScale::TIME_FORMAT)

    xml.transaction :application_id => transaction[:application_id],
                    :timestamp      => timestamp do
      transaction[:usage].each do |metric_id, value|
        xml.value value, :metric_id => metric_id
      end
    end
  end
end
