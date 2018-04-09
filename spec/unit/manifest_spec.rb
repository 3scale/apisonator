module ThreeScale
  module Backend
    describe Manifest do
      describe '.thread_safe?' do
        it 'returns false' do
          expect(described_class.thread_safe?).to eq(false)
        end

      end

      describe '.compute_workers' do
        let(:num_cpus) { ThreeScale::Backend::Util.number_of_cpus }

        it 'returns PUMA_WORKERS_CPUMULT * <number of CPUs> if no PUMA_WORKERS environment variable is set' do
          env_copy = ENV.to_h
          env_copy.delete('PUMA_WORKERS')
          stub_const('ENV', env_copy)
          expect(described_class.compute_workers(num_cpus))
            .to eq(num_cpus*described_class.singleton_class.const_get(:PUMA_WORKERS_CPUMULT))
        end

        it 'returns 0 if fork is not usable' do
          stub_const('ENV', ENV.to_h.merge('PUMA_WORKERS' => '3'))
          allow(Process).to receive(:respond_to?).with(:fork).and_return(false)
          expect(described_class.compute_workers(num_cpus)).to eq(0)
        end

        it 'returns the specified number of workers in PUMA_WORKERS when set' do
          stub_const('ENV', ENV.to_h.merge('PUMA_WORKERS' => '3'))
          expect(described_class.compute_workers(ENV['PUMA_WORKERS'])).to eq(3)
        end

        it 'returns an exception when PUMA_WORKERS is not a number' do
          stub_const('ENV', ENV.to_h.merge('PUMA_WORKERS' => 'test'))
          expect { described_class.compute_workers(ENV['PUMA_WORKERS']) }.to raise_error(ArgumentError)
        end

        it 'returns PUMA_WORKERS_CPUMULT * <number of CPUs> when PUMA_WORKERS environment variable is empty' do
          stub_const('ENV', ENV.to_h.merge('PUMA_WORKERS' => ''))
          expect(described_class.compute_workers(num_cpus))
            .to eq(num_cpus*described_class.singleton_class.const_get(:PUMA_WORKERS_CPUMULT))
        end

      end
    end
  end
end
