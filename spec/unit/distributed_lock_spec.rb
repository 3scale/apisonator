module ThreeScale
  module Backend
    describe DistributedLock do
      # TTL does not matter much, but some of these tests assume that it is
      # long enough so the key does not expire while the test is still running.
      let(:ttl) { 60 }
      let(:resource) { 'test_resource' }
      let(:storage) { ThreeScale::Backend::Storage.instance }
      subject { DistributedLock.new(resource, ttl, storage) }

      let(:lock_storage_key) { subject.send(:lock_storage_key) }

      describe '#lock' do
        context 'when the lock can be acquired' do
          it 'returns the key used to acquire the lock' do
            expect(subject.lock).to eq subject.current_lock_key
          end

          it 'prevents others from acquiring the lock' do
            subject.lock
            expect(subject.lock).to be nil
          end

          it 'sets the appropriate TTL to the associated key in the storage' do
            subject.lock

            # <= because we can't guarantee that less than 1 sec has passed
            expect(storage.ttl(lock_storage_key)).to be <= ttl
          end
        end

        context 'when the lock cannot be acquired' do
          before { subject.lock }

          it 'returns nil' do
            expect(subject.lock).to be nil
          end
        end
      end

      describe '#unlock' do
        it 'releases the lock, so it can be acquired again' do
          subject.unlock
          expect(subject.lock).not_to be nil
        end
      end

      describe '#current_lock_key' do
        context 'when there is a lock' do
          it 'returns the key used to lock' do
            key = subject.lock
            expect(subject.current_lock_key).to eq key
          end
        end

        context 'when there is not a lock' do
          it 'returns nil' do
            expect(subject.current_lock_key).to be nil
          end
        end
      end
    end
  end
end
