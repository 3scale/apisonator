require 'pathname'
require 'etc'
require '3scale/backend/logging'

module ThreeScale
  module Backend
    module Util
      def self.number_of_cpus
        detect_container_cpus || Etc.nprocessors
      end

      def self.root_dir
        File.expand_path(File.join(Array.new(4, '..'.freeze)),
                         Pathname.new(__FILE__).realpath)
      end

      private

      # Detect CPU quota from container cgroups (v1 or v2)
      # Returns nil if detection fails or quota is unlimited
      def self.detect_container_cpus
        read_cgroups_v2_cpu_quota || read_cgroups_v1_cpu_quota
      end

      # Read CPU quota from cgroups v2
      # Format: /sys/fs/cgroup/cpu.max contains "<quota> <period>"
      def self.read_cgroups_v2_cpu_quota
        cpu_max_path = '/sys/fs/cgroup/cpu.max'
        return nil unless File.exist?(cpu_max_path)

        content = File.read(cpu_max_path).strip
        quota, period = content.split(' ')

        return nil if quota == 'max' # unlimited quota

        quota_int = quota.to_i
        period_int = period.to_i

        return nil if quota_int <= 0 || period_int <= 0

        (quota_int.to_f / period_int).ceil
      rescue StandardError => e
        Backend.logger.warn "Getting CPU quota from cgroups v2 failed, falling back to cgroups v1: #{e.message}"
        nil
      end

      # Read CPU quota from cgroups v1
      # Uses cpu.cfs_quota_us and cpu.cfs_period_us
      def self.read_cgroups_v1_cpu_quota
        quota_path = '/sys/fs/cgroup/cpu/cpu.cfs_quota_us'
        period_path = '/sys/fs/cgroup/cpu/cpu.cfs_period_us'

        return nil unless File.exist?(quota_path) && File.exist?(period_path)

        quota = File.read(quota_path).strip.to_i
        period = File.read(period_path).strip.to_i

        return nil if quota <= 0 || period <= 0 # unlimited quota

        (quota.to_f / period).ceil
      rescue StandardError => e
        Backend.logger.warn "Getting CPU quota from cgroups v1 failed, falling back to Etc.nprocessors: #{e.message}"
        nil
      end
    end
  end
end
