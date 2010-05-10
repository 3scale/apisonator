require File.dirname(__FILE__) + '/../../test_helper'

module Archiver
  class S3StorageTest < Test::Unit::TestCase
    def test_store
      AWS::S3::Base.stubs(:connected?).returns(false)
      AWS::S3::Base.expects(:establish_connection!)
      AWS::S3::S3Object.expects(:store).
        with('foobar.xml','assorted foos and bars', 'test.bucket')

      storage = Archiver::S3Storage.new('test.bucket')
      storage.store('foobar.xml', 'assorted foos and bars')
    end
  end
end
