require_relative '../../../spec_helper'

resource "Services" do
  set_app ThreeScale::Backend::ServicesAPI

  get "/foo" do
    example "Just a simple test" do
      do_request

      response_body.should =~ /bar/
    end
  end
end

