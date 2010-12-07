require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Archiver
  class S3StorageTest < Test::Unit::TestCase
    def test_store
      FakeFS do
        path = File.expand_path('~')
        FileUtils.mkdir_p(path)

        File.open("#{path}/.aws.yml", 'w') do |io|
          io << "access_key_id: my-access-key-id\nsecret_access_key: my-secret-access-key\n"
        end

        AWS::S3::Base.stubs(:connected?).returns(false)

        AWS::S3::Base.expects(:establish_connection!).
          with(:access_key_id     => 'my-access-key-id',
               :secret_access_key => 'my-secret-access-key',
               :use_ssl           => true)

        AWS::S3::S3Object.expects(:store).
          with('foobar.xml','assorted foos and bars', 'test.bucket')

        storage = Archiver::S3Storage.new('test.bucket')
        storage.store('foobar.xml', 'assorted foos and bars')
      end
    end
  end
end
