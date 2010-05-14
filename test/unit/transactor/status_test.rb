require File.dirname(__FILE__) + '/../../test_helper'

module Transactor
  class StatusTest < Test::Unit::TestCase
    def test_xml_serialization
      contract = Contract.new(:plan_name => 'awesome')
      status   = Transactor::Status.new(contract)

      doc = Nokogiri::XML(status.to_xml)
      assert_equal 'awesome', doc.at('status:root plan').content
    end
  end
end
