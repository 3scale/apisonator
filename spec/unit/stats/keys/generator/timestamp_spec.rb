require_relative '../../../../spec_helper'

module ThreeScale
  module Backend
    module Stats
      module Keys
        module Generator
          describe Timestamp do
            describe '.get_time_generator' do
              def get_permanent_service_granularities
                svc_grn = Stats::Common::PERMANENT_SERVICE_GRANULARITIES
                svc_grn = svc_grn.map {|g| g.to_s}
                svc_grn.to_set
              end

              def get_permanent_expanded_granularities
                svc_grn = Stats::Common::PERMANENT_EXPANDED_GRANULARITIES
                svc_grn = svc_grn.map {|g| g.to_s}
                svc_grn.to_set
              end

              def get_granularities_from_generator(time_gen)
                # Results from Timestamp generator have the format:
                # [granularity:date, granularity_index, [timestamp]]
                results = time_gen.map { |r| r[0].split(":")[0]}
                results.uniq.to_set
              end

              def get_limits(start_grn, start_ts, end_grn, end_ts)
                lim_start = Stats::Keys::Index.new.tap do |idx|
                  idx.granularity = start_grn
                  idx.ts = start_ts
                end
                lim_end = Stats::Keys::Index.new.tap do |idx|
                  idx.granularity = end_grn
                  idx.ts = end_ts
                end
                [lim_start, lim_end]
              end

              # def get_indexed_granularities(granularities)
              #   res = {}
              #   granularities.each_with_index do |grn, idx|
              #     res[grn.to_sym] = idx
              #     res[idx] = grn.to_sym
              #   end
              #   res
              # end

              # let(:indexed_svc_grn) get_indexed_granularities(Stats::Common::PERMANENT_SERVICE_GRANULARITIES)
              # let(:indexed_exp_grn) get_indexed_granularities(Stats::Common::PERMANENT_EXPANDED_GRANULARITIES)

              def get_indexed_granularities(metric_type)
                metric_type.to_sym == :service ? Stats::Common::PERMANENT_SVC_GRN_IDX : Stats::Common::PERMANENT_EXP_GRN_IDX
              end

              let(:service_context) do
                ServiceContext.new.tap do |svc|
                  svc.from = Time.parse("2018072810").to_i
                  svc.to = Time.parse("2018072811").to_i
                end
              end

              it 'returns an Enumerator object' do
                limits = nil
                metric_type = :application
                time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                expect(time_gen).to be_an(Enumerator)
              end

              shared_examples "hourly granularity shared examples" do
                let(:idx_granularities) { get_indexed_granularities(metric_type) }
                context "and non-nil limits" do
                  it 'with simple values' do
                    # For some reason reindent breaks the indentation format when this method is called
                    limits = get_limits(idx_granularities[:hour], Time.parse("2018071015").utc.to_i,
                    idx_granularities[:hour], Time.parse("2018071016").utc.to_i)
                    time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                    expected_results = [
                      ["hour:2018071015", idx_granularities[:hour], Time.parse("2018071015").utc.to_i],
                      ["hour:2018071016", idx_granularities[:hour], Time.parse("2018071016").utc.to_i]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                  end

                  it 'with values that should be compacted in the key name' do
                    limits = get_limits(idx_granularities[:hour], Time.parse("2018071010").utc.to_i,  idx_granularities[:hour],  Time.parse("2018071011").utc.to_i)
                    time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                    expected_results = [
                      ["hour:201807101", idx_granularities[:hour], Time.parse("2018071010").utc.to_i],
                      ["hour:2018071011", idx_granularities[:hour], Time.parse("2018071011").utc.to_i]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                  end
                end
              end

              shared_examples "daily granularity shared examples" do
                let(:idx_granularities) { get_indexed_granularities(metric_type) }
                context "and non-nil limits" do
                  it 'with simple values' do
                    limits = get_limits(idx_granularities[:day], Time.parse("2018071015").utc.to_i, idx_granularities[:day], Time.parse("2018071116").utc.to_i)
                    time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                    expected_results = [
                      ["day:20180710", idx_granularities[:day], Time.parse("20180710").utc.to_i],
                      ["day:20180711", idx_granularities[:day], Time.parse("20180711").utc.to_i]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                  end
                end
              end

              shared_examples "weekly granularity shared examples" do
                let(:idx_granularities) { get_indexed_granularities(metric_type) }
                context "and non-nil limits" do
                  it 'with simple values' do
                    limits = get_limits( idx_granularities[:week], Time.parse("2018071015").utc.to_i, idx_granularities[:week], Time.parse("2018072512").utc.to_i)
                    time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                    expected_results = [
                      ["week:20180709", idx_granularities[:week], Time.parse("20180709").utc.to_i],
                      ["week:20180716", idx_granularities[:week], Time.parse("20180716").utc.to_i],
                      ["week:20180723", idx_granularities[:week], Time.parse("20180723").utc.to_i]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                  end
                end
              end

              shared_examples "monthly granularity shared examples" do
                let(:idx_granularities) { get_indexed_granularities(metric_type) }
                context "and non-nil limits" do
                  it 'with simple values' do
                    limits = get_limits(idx_granularities[:month], Time.parse("2018091015").utc.to_i, idx_granularities[:month], Time.parse("2018112512").utc.to_i)
                    time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                    expected_results = [
                      ["month:20180901", idx_granularities[:month], Time.parse("20180901").utc.to_i],
                      ["month:20181001", idx_granularities[:month], Time.parse("20181001").utc.to_i],
                      ["month:20181101", idx_granularities[:month], Time.parse("20181101").utc.to_i]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                  end
                end
              end

              #yearly granularity is not used on :service metric_type
              shared_examples "yearly granularity shared examples" do
                let(:idx_granularities) { get_indexed_granularities(metric_type) }
                let(:service_context) do
                  ServiceContext.new.tap do |svc|
                    svc.from = Time.parse("2016072810").to_i
                    svc.to = Time.parse("2022072811").to_i
                  end
                end

                context "and non-nil limits" do
                  it 'with simple values' do
                    limits = get_limits(idx_granularities[:year], Time.parse("2018091015").utc.to_i, idx_granularities[:year], Time.parse("2020112512").utc.to_i )
                    time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                    expected_results = [
                      ["year:20180101", idx_granularities[:year], Time.parse("20180101").utc.to_i],
                      ["year:20190101", idx_granularities[:year], Time.parse("20190101").utc.to_i],
                      ["year:20200101", idx_granularities[:year], Time.parse("20200101").utc.to_i]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                  end
                end
              end

              shared_examples "eternity granularity shared examples" do
                let(:idx_granularities) { get_indexed_granularities(metric_type) }
                context "and non-nil limits" do
                  it 'with simple values' do
                    limits = get_limits(idx_granularities[:eternity], nil, nil, nil)
                    time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                    expected_results = [
                      ["eternity", idx_granularities[:eternity]]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                  end
                end
              end

              context 'when metric_type parameter is "service"' do
                let (:metric_type) { :service }
                context 'and limits parameter is nil' do
                  let(:limits) { nil }
                  it 'returns keys containing all the defined types of granularities' do
                    time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                    gen_grn = get_granularities_from_generator(time_gen)
                    svc_grn = get_permanent_service_granularities
                    expect(gen_grn).to eq svc_grn
                  end
                end

                include_examples "hourly granularity shared examples"
                include_examples "daily granularity shared examples"
                include_examples "weekly granularity shared examples"
                include_examples "monthly granularity shared examples"
                include_examples "eternity granularity shared examples"
              end

              context 'when metric_type parameter is "application"' do
                let (:metric_type) { :application }
                context 'and limits parameter is nil' do
                  let(:limits) { nil }
                  it 'returns keys containing all the defined types of granularities' do
                    time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                    gen_grn = get_granularities_from_generator(time_gen)
                    svc_grn = get_permanent_expanded_granularities
                    expect(gen_grn).to eq svc_grn
                  end
                end

                context 'and limits parameter is not nil' do
                  let(:service_context) do
                    ServiceContext.new.tap do |svc|
                      svc.from = Time.parse("2018071014").to_i
                      svc.to = Time.parse("2018071017").to_i
                    end
                  end

                  context 'hour granularity is correctly generated' do

                    it 'traverses between granularities correctly' do
                      metric_type = :application
                      limits = get_limits(Stats::Common::PERMANENT_EXP_GRN_IDX[:month], Time.parse("2018071015").utc.to_i, Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071016").utc.to_i)
                      time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                      expected_results = [
                        ["month:20180701",  Stats::Common::PERMANENT_EXP_GRN_IDX[:month], Time.parse("20180701").utc.to_i],
                        ["week:20180709",   Stats::Common::PERMANENT_EXP_GRN_IDX[:week], Time.parse("20180709").utc.to_i],
                        ["day:20180710",    Stats::Common::PERMANENT_EXP_GRN_IDX[:day], Time.parse("20180710").utc.to_i],
                        ["hour:2018071014", Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071014").utc.to_i],
                        ["hour:2018071015", Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071015").utc.to_i],
                        ["hour:2018071016", Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071016").utc.to_i]
                      ]
                      results = []
                      time_gen.each { |r| results << r }
                      expect(results).to eq expected_results
                    end
                  end
                end

                include_examples "hourly granularity shared examples"
                include_examples "daily granularity shared examples"
                include_examples "weekly granularity shared examples"
                include_examples "monthly granularity shared examples"
                include_examples "yearly granularity shared examples"
                include_examples "eternity granularity shared examples"

              end

              context 'when metric_type parameter is "user"' do
                let (:metric_type) { :user }
                context 'and limits parameter is nil' do
                  let(:limits) { nil }
                  it 'returns keys containing all the defined types of granularities' do
                    time_gen = Timestamp.new(service_context, limits, metric_type).get_time_generator
                    gen_grn = get_granularities_from_generator(time_gen)
                    svc_grn = get_permanent_expanded_granularities
                    expect(gen_grn).to eq svc_grn
                  end
                end

                include_examples "hourly granularity shared examples"
                include_examples "daily granularity shared examples"
                include_examples "weekly granularity shared examples"
                include_examples "monthly granularity shared examples"
                include_examples "yearly granularity shared examples"
                include_examples "eternity granularity shared examples"

              end
            end
          end
        end
      end
    end
  end
end