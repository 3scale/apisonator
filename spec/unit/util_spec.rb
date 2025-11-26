require_relative '../../lib/3scale/backend/util'

module ThreeScale
  module Backend
    describe Util do
      describe '.number_of_cpus' do
        context 'with cgroups v2' do
          let(:cpu_max_path) { '/sys/fs/cgroup/cpu.max' }

          before do
            allow(File).to receive(:exist?).and_call_original
            allow(File).to receive(:exist?).with(cpu_max_path).and_return(true)
          end

          it 'returns the calculated CPU quota from cpu.max' do
            # Simulate 2 CPUs: quota=200000, period=100000
            allow(File).to receive(:read).with(cpu_max_path).and_return("200000 100000\n")
            expect(described_class.number_of_cpus).to eq(2)
          end

          it 'returns the ceiling of fractional CPU quota' do
            # Simulate 1.5 CPUs: quota=150000, period=100000 -> ceil to 2
            allow(File).to receive(:read).with(cpu_max_path).and_return("150000 100000\n")
            expect(described_class.number_of_cpus).to eq(2)
          end

          it 'returns the ceiling for small fractional CPU quota' do
            # Simulate 0.5 CPUs: quota=50000, period=100000 -> ceil to 1
            allow(File).to receive(:read).with(cpu_max_path).and_return("50000 100000\n")
            expect(described_class.number_of_cpus).to eq(1)
          end

          it 'falls back to Etc.nprocessors when quota is "max"' do
            allow(File).to receive(:read).with(cpu_max_path).and_return("max 100000\n")
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end

          it 'falls back to Etc.nprocessors when quota is zero' do
            allow(File).to receive(:read).with(cpu_max_path).and_return("0 100000\n")
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end

          it 'falls back to Etc.nprocessors when period is zero' do
            allow(File).to receive(:read).with(cpu_max_path).and_return("100000 0\n")
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end

          it 'falls back to Etc.nprocessors when reading fails' do
            allow(File).to receive(:read).with(cpu_max_path).and_raise(Errno::EACCES)
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end

          it 'falls back to Etc.nprocessors with malformed content' do
            allow(File).to receive(:read).with(cpu_max_path).and_return("invalid\n")
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end
        end

        context 'with cgroups v1' do
          let(:cpu_max_path) { '/sys/fs/cgroup/cpu.max' }
          let(:quota_path) { '/sys/fs/cgroup/cpu/cpu.cfs_quota_us' }
          let(:period_path) { '/sys/fs/cgroup/cpu/cpu.cfs_period_us' }

          before do
            allow(File).to receive(:exist?).and_call_original
            # cgroups v2 file doesn't exist
            allow(File).to receive(:exist?).with(cpu_max_path).and_return(false)
            # cgroups v1 files exist
            allow(File).to receive(:exist?).with(quota_path).and_return(true)
            allow(File).to receive(:exist?).with(period_path).and_return(true)
          end

          it 'returns the calculated CPU quota from cfs files' do
            # Simulate 4 CPUs: quota=400000, period=100000
            allow(File).to receive(:read).with(quota_path).and_return("400000\n")
            allow(File).to receive(:read).with(period_path).and_return("100000\n")
            expect(described_class.number_of_cpus).to eq(4)
          end

          it 'returns the ceiling of fractional CPU quota' do
            # Simulate 2.5 CPUs: quota=250000, period=100000 -> ceil to 3
            allow(File).to receive(:read).with(quota_path).and_return("250000\n")
            allow(File).to receive(:read).with(period_path).and_return("100000\n")
            expect(described_class.number_of_cpus).to eq(3)
          end

          it 'falls back to Etc.nprocessors when quota is -1 (unlimited)' do
            allow(File).to receive(:read).with(quota_path).and_return("-1\n")
            allow(File).to receive(:read).with(period_path).and_return("100000\n")
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end

          it 'falls back to Etc.nprocessors when quota is zero' do
            allow(File).to receive(:read).with(quota_path).and_return("0\n")
            allow(File).to receive(:read).with(period_path).and_return("100000\n")
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end

          it 'falls back to Etc.nprocessors when period is zero' do
            allow(File).to receive(:read).with(quota_path).and_return("100000\n")
            allow(File).to receive(:read).with(period_path).and_return("0\n")
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end

          it 'falls back to Etc.nprocessors when quota file is missing' do
            allow(File).to receive(:exist?).with(quota_path).and_return(false)
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end

          it 'falls back to Etc.nprocessors when period file is missing' do
            allow(File).to receive(:exist?).with(period_path).and_return(false)
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end

          it 'falls back to Etc.nprocessors when reading fails' do
            allow(File).to receive(:read).with(quota_path).and_raise(Errno::EACCES)
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end
        end

        context 'without cgroups (bare metal or VM)' do
          let(:cpu_max_path) { '/sys/fs/cgroup/cpu.max' }
          let(:quota_path) { '/sys/fs/cgroup/cpu/cpu.cfs_quota_us' }
          let(:period_path) { '/sys/fs/cgroup/cpu/cpu.cfs_period_us' }

          before do
            allow(File).to receive(:exist?).and_call_original
            allow(File).to receive(:exist?).with(cpu_max_path).and_return(false)
            allow(File).to receive(:exist?).with(quota_path).and_return(false)
            allow(File).to receive(:exist?).with(period_path).and_return(false)
          end

          it 'falls back to Etc.nprocessors' do
            expect(described_class.number_of_cpus).to eq(Etc.nprocessors)
          end
        end
      end
    end
  end
end
