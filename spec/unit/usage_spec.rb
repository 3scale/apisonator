require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe Usage do
      include TestHelpers::Sequences

      let(:a_base_value) { 7 }
      let(:a_set_value) { 47 }
      let(:a_set_str) { "##{a_set_value}" }
      let(:an_increment_str) { '69' }
      let(:an_increment_value) { an_increment_str.to_i }
      let(:garbage) { 'garbage' }
      let(:not_sets) { [an_increment_str, garbage] }

      describe '.application_usage_for_limits' do
        let(:current_time) { Time.now }
        let(:provider_key) { 'a_provider_key' }
        let(:service_id) { next_id }
        let(:plan_id) { next_id }
        let(:app_id) { next_id }

        let(:metrics) do
          [
            { service_id: service_id, id: next_id, name: 'm1' },
            { service_id: service_id, id: next_id, name: 'm2' }
          ]
        end

        # Create one limit for each metric
        let(:usage_limits) do
          [
            { service_id: service_id, plan_id: plan_id, metric_id: metrics[0][:id], hour: 10 },
            { service_id: service_id, plan_id: plan_id, metric_id: metrics[1][:id], hour: 15 }
          ]
        end

        before do
          Service.save!(provider_key: provider_key, id: service_id)
          Application.save(service_id: service_id, id: app_id, plan_id: plan_id, state: :active)
          metrics.each { |metric| Metric.save(metric) }
          usage_limits.each { |limit| UsageLimit.save(limit) }

          # Report something for both metrics
          with_resque do
            Timecop.freeze(current_time) do
              Transactor.report(
                provider_key,
                service_id,
                0 => { app_id: app_id, usage: { metrics[0][:name] => 1 } },
                1 => { app_id: app_id, usage: { metrics[1][:name] => 2 } }
              )
            end
          end

          ThreeScale::Backend::WorkerSync.new(one_off: true)
        end

        it 'returns only the usages that affect the limits received in the params' do
          limits = UsageLimit.load_for_affecting_metrics(
            service_id, plan_id, [metrics[0][:id]]
          )

          usages = Usage.application_usage_for_limits(
            Application.load(service_id, app_id), current_time.utc, limits
          )

          expect(usages[Period::Hour][(metrics[0][:id]).to_s]).to eq 1

          # The second metric does not apply to the usage_limit passed in the
          # params, so it should not appear in the result.
          expect(usages[Period::Hour][(metrics[1][:id]).to_s]).to be_nil
        end
      end

      describe '.is_set?' do
        it 'returns truthy when a set is specified' do
          expect(described_class.is_set? a_set_str).to be_truthy
        end

        it 'returns falsey when a non-set is specified' do
          not_sets.each do |item|
            expect(described_class.is_set? item).to be_falsey
          end
        end
      end

      describe '.get_from' do
        context 'when an increment is specified' do
          it 'returns the base value plus the increment' do
            expect(
              described_class.get_from an_increment_str, a_base_value
            ).to be(a_base_value + an_increment_value)
          end

          it 'returns just the increment when no base is specified' do
            expect(
              described_class.get_from an_increment_str
            ).to be(an_increment_value)
          end
        end

        context 'when a set is specified' do
          it 'returns the set value regardless of the base' do
            expect(
              described_class.get_from a_set_str, a_base_value
            ).to be(a_set_value)
          end

          it 'returns just the set value when no base is specified' do
            expect(
              described_class.get_from a_set_str
            ).to be(a_set_value)
          end
        end
      end
    end
  end
end
