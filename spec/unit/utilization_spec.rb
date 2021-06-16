require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe Utilization do
      include TestHelpers::Sequences

      let(:provider_key) { 'a_provider_key' }
      let(:service_id) { next_id }
      let(:plan_id) { next_id }
      let(:metric) { { service_id: service_id, id: next_id, name: 'm1' } }
      let(:limit_period) { :hour }
      let(:max_value) { 10 }
      let(:current_val) { 5 }
      let(:usage_limit) do
        {
          service_id: service_id,
          plan_id: plan_id,
          metric_id: metric[:id],
          limit_period => max_value
        }
      end

      before do
        Service.save!(provider_key: provider_key, id: service_id)
        Metric.save(metric)
        UsageLimit.save(usage_limit)
      end

      describe '#ratio' do
        it 'returns current_value / max_value' do
          limit = UsageLimit.load_for_affecting_metrics(service_id, plan_id, [metric[:id]]).first
          utilization = Utilization.new(limit, current_val)

          expect(utilization.ratio).to eq current_val/max_value.to_f
        end

        context 'when the max value is 0' do
          let(:other_metric) { { service_id: service_id, id: next_id, name: 'other_metric' } }
          let(:limit_with_max_0) do
            {
              service_id: service_id,
              plan_id: plan_id,
              metric_id: other_metric[:id],
              limit_period => 0
            }
          end

          before do
            Metric.save(other_metric)
            UsageLimit.save(limit_with_max_0)
          end

          it 'returns 0' do
            limit = UsageLimit.load_for_affecting_metrics(
              service_id, plan_id, [other_metric[:id]]
            ).first

            utilization = Utilization.new(limit, 0)

            expect(utilization.ratio).to be_zero
          end
        end
      end

      describe '#to_s' do
        it 'returns a str in the format needed by the Alerts class' do
          limit = UsageLimit.load_for_affecting_metrics(service_id, plan_id, [metric[:id]]).first
          utilization = Utilization.new(limit, current_val)

          expect(utilization.to_s)
            .to eq("#{metric[:name]} per #{limit_period}: #{current_val}/#{limit.value}")
        end
      end

      describe '#<=>' do
        let(:other_metric) { { service_id: service_id, id: next_id, name: 'other_metric' } }
        let(:other_limit) do
          {
            service_id: service_id,
            plan_id: plan_id,
            metric_id: other_metric[:id],
            limit_period => max_value*2
          }
        end

        before do
          Metric.save(other_metric)
          UsageLimit.save(other_limit)
        end

        it 'compares based on the ratio' do
          limit = UsageLimit.load_for_affecting_metrics(
            service_id, plan_id, [metric[:id]]
          ).first

          other_limit = UsageLimit.load_for_affecting_metrics(
            service_id, plan_id, [other_metric[:id]]
          ).first

          utilization = Utilization.new(limit, current_val)
          other_utilization = Utilization.new(other_limit, current_val)

          # "other_limit" has a max that's twice the max defined in "limit", and
          # both have the same usage, so the utilization should be lower for
          # "other_limit"
          expect(other_utilization < utilization).to be true
        end

        context 'when the ratio is 0 in both' do
          let(:metric) { { service_id: service_id, id: next_id, name: 'some_metric' } }
          let(:usage_limits) do
            [
              {
                service_id: service_id,
                plan_id: plan_id,
                metric_id: metric[:id],
                hour: 0
              },
              {
                service_id: service_id,
                plan_id: plan_id,
                metric_id: metric[:id],
                day: 100
              }
            ]
          end

          before do
            Metric.save(metric)
            usage_limits.each { |limit| UsageLimit.save(limit) }
          end

          it 'considers one with max_val = 0 to be lesser than the other' do
            limits = UsageLimit.load_for_affecting_metrics(
              service_id, plan_id, [metric[:id]]
            )

            utilizations = limits.map { |limit| Utilization.new(limit, 0) }

            expect(utilizations.min.max_value).to be_zero
          end
        end
      end

      # Create a separate context for these functions because they use the same
      # vars (provider_key, service_id, etc.) and setup.
      context 'max functions' do
        let(:current_time) { Time.now }
        let(:provider_key) { 'some_provider_key' }
        let(:service_id) { next_id }
        let(:app_id) { next_id }
        let(:plan_id) { next_id }

        let(:metrics) do
          [
            { service_id: service_id, id: next_id, name: 'm1' },
            { service_id: service_id, id: next_id, name: 'm2' }
          ]
        end

        let(:metric_ids) { metrics.map { |metric| metric[:id] } }

        let(:usage_limits) do
          [
            {
              service_id: service_id,
              plan_id: plan_id,
              metric_id: metrics[0][:id],
              hour: 10
            },
            {
              service_id: service_id,
              plan_id: plan_id,
              metric_id: metrics[1][:id],
              hour: 20
            }
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
                0 => { app_id: app_id, usage: { metrics[0][:name] => 1 } }, # 10% util.
                1 => { app_id: app_id, usage: { metrics[1][:name] => 10 } } # 50% util.
              )
            end
          end

          ThreeScale::Backend::WorkerSync.new(one_off: true)
        end

        describe '.max_in_all_metrics' do
          it 'returns the max utilization taking into account all the metrics' do
            max = Timecop.freeze(current_time) do
              Utilization.max_in_all_metrics(service_id, app_id)
            end

            expect(max.ratio).to eq 0.5
            expect(max.metric_id).to eq metrics[1][:id]
          end

          it 'raises when the app does not exist' do
            expect { Utilization.max_in_all_metrics(service_id, 'invalid') }
              .to raise_error(ApplicationNotFound)
          end
        end

        describe '.max_in_metrics' do
          it 'returns the max utilization that affects any of the metrics received' do
            max = Timecop.freeze(current_time) do
              Utilization.max_in_metrics(service_id, app_id, [metrics[0][:id]])
            end

            # Notice that there's an utilization of 0.5 for the other metric,
            # but it was not in the params, so it should not be considered when
            # calculating the max.
            expect(max.ratio).to eq 0.1
            expect(max.metric_id).to eq metrics[0][:id]
          end

          it 'returns nil if the metrics provided are invalid' do
            expect(Utilization.max_in_metrics(service_id, app_id, ['invalid'])).to be_nil
          end

          it 'raises when the app does not exist' do
            expect { Utilization.max_in_metrics(service_id, 'invalid', metric_ids) }
              .to raise_error(ApplicationNotFound)
          end
        end
      end
    end
  end
end
