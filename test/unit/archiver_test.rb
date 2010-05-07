require File.dirname(__FILE__) + '/../test_helper'
require 'nokogiri'

class ArchiverTest < Test::Unit::TestCase
  def setup
    config_path = ThreeScale::Backend.configuration_file
    config = File.read(config_path)

    FakeFS.activate!
    File.open(config_path, 'w') { |io| io.write(config) }
  end

  def teardown
    FakeFS.deactivate!
  end

  def test_append_creates_partial_file_if_it_does_not_exist
    transaction = {:service   => 4001,
                   :cinstance => 5001,
                   :usage     => {6001 => 1, 6002 => 224},
                   :timestamp => Time.utc(2010, 4, 12, 21, 44),
                   :client_ip => '1.2.3.4'}

    Archiver.append(transaction)

    filename = "/tmp/transactions/service-4001/20100412.xml.part"
    assert File.exists?(filename), 'File does not exist.'

    content = File.read(filename)
    content = "<transactions>#{content}</transactions>"

    doc = Nokogiri::XML(content)

    assert_not_nil doc.at_css('transaction')
      assert_equal '5001', doc.at_css('transaction contract_id').content
      assert_equal '2010-04-12 21:44:00', doc.at_css('transaction timestamp').content

      assert_not_nil doc.at_css('transaction values')
        assert_equal '1',   doc.at_css('transaction values value[metric_id = "6001"]').content
        assert_equal '224', doc.at_css('transaction values value[metric_id = "6002"]').content

      assert_equal '1.2.3.4', doc.at_css('transaction ip').content 
  end

  # test 'archive appends to existing partial file' do
  #   filename = "/tmp/transactions/4001/20100412.xml.part"

  #   # Data already existing in the file
  #   xml = Builder::XmlMarkup.new
  #   xml.transaction do
  #     xml.contract_id '5001'
  #     xml.created_at  '2010-04-12 21:44:00 +0200'
  #     xml.ip          '1.2.3.4'
  #     xml.values do
  #       xml.value '1',   :metric_id => '6001'
  #       xml.value '224', :metric_id => '6002'
  #     end
  #   end

  #   File.open(filename, 'w') { |io| io.write(xml.target!) }

  #   transaction = {:provider_id => 4001,
  #                  :contract_id => 5002,
  #                  :usage       => {6001 => 1, 6002 => 835},
  #                  :created_at  => time(2010, 4, 12, 23, 19),
  #                  :ip          => '1.2.3.5'}
  #   

  #   Backend::Archiver.append(transaction)

  #   content = File.read(filename)
  #   content = "<transactions>#{content}</transactions>"

  #   assert_select_in content, 'transactions' do
  #     assert_select_in 'transaction' do
  #       assert_select_in 'contract_id', '5001'
  #       assert_select_in 'created_at', '2010-04-12 21:44:00 +0200'

  #       assert_select_in 'values' do
  #         assert_select_in 'value[metric_id=?]', '6001', '1'
  #         assert_select_in 'value[metric_id=?]', '6002', '224'
  #       end

  #       assert_select_in 'ip', '1.2.3.4'
  #     end
  #     
  #     assert_select_in 'transaction' do
  #       assert_select_in 'contract_id', '5002'
  #       assert_select_in 'created_at', '2010-04-12 23:19:00 +0200'

  #       assert_select_in 'values' do
  #         assert_select_in 'value[metric_id=?]', '6001', '1'
  #         assert_select_in 'value[metric_id=?]', '6002', '835'
  #       end

  #       assert_select_in 'ip', '1.2.3.5'
  #     end
  #   end
  # end

  # test 'store sends complete files to the archive storage' do
  #   Backend::Archiver.append(:provider_id => 4001,
  #                            :contract_id => 5002,
  #                            :usage       => {6001 => 1},
  #                            :created_at  => time(2010, 4, 12, 23, 19))

  #   Timecop.freeze(2010, 4, 13, 12, 30) do
  #     storage = stub('storage')
  #     storage.expects(:store).with('4001/20100412/foo.xml.gz', anything)

  #     Backend::Archiver.store(:storage => storage, :tag => 'foo')
  #   end
  # end
  # 
  # test 'store does not send incomplete files to the archive storage' do
  #   Backend::Archiver.append(:provider_id => 4001,
  #                            :contract_id => 5002,
  #                            :usage       => {6001 => 1},
  #                            :created_at  => time(2010, 4, 12, 23, 19))

  #   Timecop.freeze(2010, 4, 12, 23, 44) do
  #     storage = stub('storage')
  #     storage.expects(:store).with('4001/20100412/foo.xml.gz', anything).never

  #     Backend::Archiver.store(:storage => storage, :tag => 'foo')
  #   end
  # end

  # test 'store makes the files valid xml and compresses them' do
  #   Backend::Archiver.append(:provider_id => 4001,
  #                            :contract_id => 5002,
  #                            :usage       => {6001 => 1},
  #                            :created_at  => time(2010, 4, 12, 23, 19))

  #   Timecop.freeze(2010, 4, 13, 12, 30) do
  #     storage = Backend::Archiver::MemoryStorage.new
  #     
  #     Backend::Archiver.store(:storage => storage, :tag => 'foo')

  #     raw_content = storage['4001/20100412/foo.xml.gz']

  #     begin
  #       gzip_io = Zlib::GzipReader.new(StringIO.new(raw_content))
  #       content = gzip_io.read
  #     ensure
  #       gzip_io.close rescue nil
  #     end

  #     assert_select_in content, 'transactions:root[provider_id=?]', '4001'
  #   end
  # end

  # test 'cleanup deletes processed partial files older than two days' do
  #   Backend::Archiver.append(:provider_id => 4001,
  #                            :contract_id => 5002,
  #                            :usage       => {6001 => 1},
  #                            :created_at  => time(2010, 4, 12, 23, 19))
  #   
  #   path = '/tmp/transactions/4001/20100412.xml.part'

  #   Timecop.freeze(2010, 4, 14, 12, 30) do
  #     assert_change :of => lambda { File.exist?(path) }, :from => true, :to => false do 
  #       Backend::Archiver.cleanup
  #     end
  #   end
  # end
  # 
  # test 'cleanup does not delete processed partial files not older than two days' do
  #   Backend::Archiver.append(:provider_id => 4001,
  #                            :contract_id => 5002,
  #                            :usage       => {6001 => 1},
  #                            :created_at  => time(2010, 4, 12, 23, 19))
  #   
  #   path = '/tmp/transactions/4001/20100412.xml.part'

  #   Timecop.freeze(2010, 4, 13, 12, 30) do
  #     assert_no_change :of => lambda { File.exist?(path) } do 
  #       Backend::Archiver.cleanup
  #     end
  #   end
  # end
end
