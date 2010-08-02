require File.dirname(__FILE__) + '/../test_helper'

class StorageTest < Test::Unit::TestCase
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
  end

  def test_basic_operations
    assert_nil @storage.get('foo')
    @storage.set('foo', 'bar')
    assert_equal 'bar', @storage.get('foo')
  end

  def test_restore_backup_replays_the_commands_from_the_backup_file
    write_backup_file('set foo stuff', 'set bar junk')

    @storage.restore_backup
    assert_equal 'stuff', @storage.get('foo')
    assert_equal 'junk',  @storage.get('bar')
  end

  def test_restore_backup_handles_commands_with_arguments_with_whitespaces
    write_backup_file("rpush foo #{Yajl::Encoder.encode('stuff' => 'one two')}")

    @storage.restore_backup
    item = Yajl::Parser.parse(@storage.lpop('foo'))

    assert_equal 'one two', item['stuff']    
  end

  def test_restore_backup_deletes_the_backup_file
    write_backup_file('set foo stuff')
    
    @storage.restore_backup
    assert !File.exists?(Storage::Failover::DEFAULT_BACKUP_FILE), 'File should not exist'
  end

  private

  def write_backup_file(*commands)
    FileUtils.mkdir_p(File.dirname(Storage::Failover::DEFAULT_BACKUP_FILE))

    File.open(Storage::Failover::DEFAULT_BACKUP_FILE, 'w') do |io|
      commands.each do |command|
        io << command << "\n"
      end
    end
  end
end
