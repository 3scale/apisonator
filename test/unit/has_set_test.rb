require File.dirname(__FILE__) + '/../test_helper'

class HasSetTest < Test::Unit::TestCase
  class Ninja
    include ThreeScale::Backend::HasSet
    has_set :weapons

    private

    def storage_key(attribute)
      "ninja/#{attribute}"
    end

    def storage
      ThreeScale::Backend::Storage.instance
    end
  end

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    @ninja = Ninja.new
  end

  test '#create_{item} stores the item in the storage' do
    @ninja.create_weapon('katana')

    assert_equal ['katana'], @storage.smembers('ninja/weapons')
  end

  test '#create_{item} returns the item created' do
    assert_equal 'shuriken', @ninja.create_weapon('shuriken')
  end

  test '#{items} returns all items from the storage' do
    @storage.sadd('ninja/weapons', 'katana')
    @storage.sadd('ninja/weapons', 'wakizashi')
    @storage.sadd('ninja/weapons', 'shuriken')

    assert_equal ['katana', 'shuriken', 'wakizashi'], @ninja.weapons.sort
  end

  test '#{items} returns empty array if no items are stored' do
    assert_equal [], @ninja.weapons
  end

  test '#delete_{item} removes an item from the storage' do
    @storage.sadd('ninja/weapons', 'katana')
    @storage.sadd('ninja/weapons', 'wakizashi')

    @ninja.delete_weapon('katana')

    assert_equal ['wakizashi'], @storage.smembers('ninja/weapons')
  end
  
  test '#delete_{item} does nothing if the item does not exist' do
    @storage.sadd('ninja/weapons', 'katana')
    @storage.sadd('ninja/weapons', 'wakizashi')

    @ninja.delete_weapon('shuriken')

    assert_equal ['katana', 'wakizashi'], @storage.smembers('ninja/weapons').sort
  end

  test '#has_{items}? returns true if at least one item is stored' do
    @storage.sadd('ninja/weapons', 'katana')

    assert @ninja.has_weapons?
  end
  
  test '#has_{items}? returns false if no items are stored' do
    assert !@ninja.has_weapons?
  end
  
  test '#has_no_{items}? returns false if at least one item is stored' do
    @storage.sadd('ninja/weapons', 'katana')

    assert !@ninja.has_no_weapons?
  end
  
  test '#has_no_{items}? returns true if no items are stored' do
    assert @ninja.has_no_weapons?
  end
  
  test '#has_{item}? returns true if the item is among the stored items' do
    @storage.sadd('ninja/weapons', 'katana')
    @storage.sadd('ninja/weapons', 'shuriken')

    assert @ninja.has_weapon?('shuriken')
  end
  
  test '#has_{item}? returns false if the item is not among the stored items' do
    @storage.sadd('ninja/weapons', 'katana')
    @storage.sadd('ninja/weapons', 'shuriken')

    assert !@ninja.has_weapon?('wakizashi')
  end
end
