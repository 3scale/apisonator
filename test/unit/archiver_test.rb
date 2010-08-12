require File.dirname(__FILE__) + '/../test_helper'

class ArchiverTest < Test::Unit::TestCase
  def setup
    FakeFS.activate!
    FileUtils.rm_rf(configuration.archiver.path)
  end

  def teardown
    FakeFS.deactivate!
  end

  def test_add_creates_partial_file_if_it_does_not_exist
    transaction = {:service_id     => '4001',
                   :application_id => '5001',
                   :usage          => {6001 => 1, 6002 => 224},
                   :timestamp      => Time.utc(2010, 4, 12, 21, 44),
                   :client_ip      => '1.2.3.4'}

    Archiver.add([transaction])

    filename = "/tmp/3scale_backend/archive/service-4001/20100412.xml.part"
    assert File.exists?(filename), "File should exist, but it doesn't."

    content = File.read(filename)
    content = "<transactions>#{content}</transactions>"

    doc = Nokogiri::XML(content)

    assert_not_nil doc.at('transaction')
      assert_equal '5001', doc.at('transaction application_id').content
      assert_equal '2010-04-12 21:44:00', doc.at('transaction timestamp').content

      assert_not_nil doc.at('transaction values')
        assert_equal '1',   doc.at('transaction values value[metric_id = "6001"]').content
        assert_equal '224', doc.at('transaction values value[metric_id = "6002"]').content

      assert_equal '1.2.3.4', doc.at('transaction ip').content 
  end

  def test_add_appends_to_existing_partial_file
    filename = "/tmp/3scale_backend/archive/service-4001/20100412.xml.part"

    # Data already existing in the file
    xml = Builder::XmlMarkup.new
    xml.transaction do
      xml.application_id '5001'
      xml.timestamp      '2010-04-12 21:44:00'
      xml.ip             '1.2.3.4'
      xml.values do
        xml.value '1',   :metric_id => '6001'
        xml.value '224', :metric_id => '6002'
      end
    end

    File.open(filename, 'w') { |io| io.write(xml.target!) }

    transaction = {:service_id     => '4001',
                   :application_id => '5002',
                   :usage          => {6001 => 1, 6002 => 835},
                   :timestamp      => Time.utc(2010, 4, 12, 23, 19),
                   :client_ip      => '1.2.3.5'}
    

    Archiver.add([transaction])

    content = File.read(filename)
    content = "<transactions>#{content}</transactions>"

    doc = Nokogiri::XML(content)

    nodes = doc.search('transaction')

    assert_equal 2, nodes.count

    assert_equal '5001', nodes[0].at('application_id').content
    assert_equal '2010-04-12 21:44:00', nodes[0].at('timestamp').content

    assert_equal '1',   nodes[0].at('values value[metric_id = "6001"]').content
    assert_equal '224', nodes[0].at('values value[metric_id = "6002"]').content

    assert_equal '1.2.3.4', nodes[0].at('ip').content


    assert_equal '5002', nodes[1].at('application_id').content
    assert_equal '2010-04-12 23:19:00', nodes[1].at('timestamp').content

    assert_equal '1',   nodes[1].at('values value[metric_id = "6001"]').content
    assert_equal '835', nodes[1].at('values value[metric_id = "6002"]').content
    
    assert_equal '1.2.3.5', nodes[1].at('ip').content
  end

  def test_store_sends_complete_files_to_the_archive_storage
    Archiver.add([{:service_id     => 4001,
                   :application_id => 5002,
                   :usage          => {6001 => 1},
                   :timestamp      => Time.utc(2010, 4, 12, 23, 19)}])

    Timecop.freeze(2010, 4, 13, 12, 30) do
      name = nil
      content = nil

      storage = stub('storage')
      storage.expects(:store).with('service-4001/20100412/foo.xml.gz', anything)

      Archiver.store(:storage => storage, :tag => 'foo')
    end
  end
  
  def test_store_does_not_send_incomplete_files_to_the_archive_storage
    Archiver.add([{:service_id     => 4001,
                   :application_id => 5002,
                   :usage          => {6001 => 1},
                   :timestamp      => Time.utc(2010, 4, 12, 23, 19)}])

    Timecop.freeze(2010, 4, 12, 23, 44) do
      storage = stub('storage')
      storage.expects(:store).with('service-4001/20100412/foo.xml.gz', anything).never

      Archiver.store(:storage => storage, :tag => 'foo')
    end
  end

  def test_store_makes_the_files_valid_xml_and_compresses_them
    Archiver.add([{:service_id     => 4001,
                   :application_id => 5002,
                   :usage          => {6001 => 1},
                   :timestamp      => Time.utc(2010, 4, 12, 23, 19)}])

    Timecop.freeze(2010, 4, 13, 12, 30) do
      name = nil
      content = nil

      storage = stub('storage')
      storage.expects(:store).with do |*args|
        name, content = *args
        true
      end
      
      Archiver.store(:storage => storage, :tag => 'foo')

      begin
        gzip_io = Zlib::GzipReader.new(StringIO.new(content))
        content = gzip_io.read
      ensure
        gzip_io.close rescue nil
      end

      doc = Nokogiri::XML(content)
      node = doc.at('transactions:root[service_id = "4001"] transaction')

      assert_not_nil node
      assert_equal '5002', node.at('application_id').content
      assert_equal '1', node.at('values value[metric_id = "6001"]').content
      assert_equal '2010-04-12 23:19:00', node.at('timestamp').content
    end
  end

  def test_cleanup_deletes_processed_partial_files_older_than_two_days
    Archiver.add([{:service_id     => 4001,
                   :application_id => 5002,
                   :usage          => {6001 => 1},
                   :timestamp      => Time.utc(2010, 4, 12, 23, 19)}])
    
    path = '/tmp/3scale_backend/archive/service-4001/20100412.xml.part'

    Timecop.freeze(2010, 4, 14, 12, 30) do
      assert  File.exist?(path), "File should exist, but it doesn't."
      Archiver.cleanup
      assert !File.exist?(path), "File should not exist, but it does."
    end
  end
  
  def test_cleanup_does_not_delete_processed_partial_files_not_older_than_two_days
    Archiver.add([{:service_id     => 4001,
                   :application_id => 5002,
                   :usage          => {6001 => 1},
                   :timestamp      => Time.utc(2010, 4, 12, 23, 19)}])
    
    path = '/tmp/3scale_backend/archive/service-4001/20100412.xml.part'

    Timecop.freeze(2010, 4, 13, 12, 30) do
      Archiver.cleanup
      assert File.exist?(path), "File should exist, but it doesn't."
    end
  end
end
