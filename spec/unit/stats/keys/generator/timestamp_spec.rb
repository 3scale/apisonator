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
              
              let(:service_context) do
                ServiceContext.new.tap do |svc|
                  svc.from = Time.parse("2018072810").to_i
                  svc.to = Time.parse("2018072811").to_i
                end
              end
              
              it 'returns an Enumerator object' do
                limits = nil
                metric_type = :application
                time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
                expect(time_gen).to be_an(Enumerator)
              end
              
              context 'when metric_type parameter is "service"' do
                let (:metric_type) { :service }
                context 'and limits parameter is nil' do
                  let(:limits) { nil }
                  it 'returns keys containing all the defined types of granularities' do
                    time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
                    gen_grn = get_granularities_from_generator(time_gen)
                    svc_grn = get_permanent_service_granularities
                    expect(gen_grn).to eq svc_grn
                  end
                end
                
                context 'and limits parameter is not nil' do
                  
                end
              end
              
              context 'when metric_type parameter is "application"' do
                let (:metric_type) { :application }
                context 'and limits parameter is nil' do
                  let(:limits) { nil }
                  it 'returns keys containing all the defined types of granularities' do
                    time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
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
                    it 'with simple values' do
                      # For some reason reindent breaks the indentation format when this method is called
                      limits = get_limits(Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071015").utc.to_i,
                      Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071016").utc.to_i)
                      
                      time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
                      expected_results = [
                        ["hour:2018071015", Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071015").utc.to_i],
                        ["hour:2018071016", Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071016").utc.to_i]
                      ]
                      results = []
                      time_gen.each { |r| results << r }
                      expect(results).to eq expected_results
                    end
                    
                    it 'with values that should be compacted in the key name' do
                      limits = get_limits(Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071010").utc.to_i,  Stats::Common::PERMANENT_EXP_GRN_IDX[:hour],  Time.parse("2018071011").utc.to_i)
                      time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
                      expected_results = [
                        ["hour:201807101", Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071010").utc.to_i],
                        ["hour:2018071011", Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071011").utc.to_i]
                      ]
                      results = []
                      time_gen.each { |r| results << r }
                      expect(results).to eq expected_results
                    end
                    
                    it 'traversing granularities' do
                      limits = get_limits(Stats::Common::PERMANENT_EXP_GRN_IDX[:month], Time.parse("2018071015").utc.to_i, Stats::Common::PERMANENT_EXP_GRN_IDX[:hour], Time.parse("2018071016").utc.to_i)
                      time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
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
                
                context 'day granularity is correctly generated' do
                  it 'with simple values' do
                    limits = get_limits(Stats::Common::PERMANENT_EXP_GRN_IDX[:day], Time.parse("2018071015").utc.to_i, Stats::Common::PERMANENT_EXP_GRN_IDX[:day], Time.parse("2018071116").utc.to_i)
                    time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
                    expected_results = [
                      ["day:20180710", Stats::Common::PERMANENT_EXP_GRN_IDX[:day], Time.parse("20180710").utc.to_i],
                      ["day:20180711", Stats::Common::PERMANENT_EXP_GRN_IDX[:day], Time.parse("20180711").utc.to_i]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                    
                  end
                end
                
                context 'week granularity is correctly generated' do
                  it 'with simple values' do
                    limits = get_limits( Stats::Common::PERMANENT_EXP_GRN_IDX[:week], Time.parse("2018071015").utc.to_i, Stats::Common::PERMANENT_EXP_GRN_IDX[:week], Time.parse("2018072512").utc.to_i)
                    time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
                    expected_results = [
                      ["week:20180709", Stats::Common::PERMANENT_EXP_GRN_IDX[:week], Time.parse("20180709").utc.to_i],
                      ["week:20180716", Stats::Common::PERMANENT_EXP_GRN_IDX[:week], Time.parse("20180716").utc.to_i],
                      ["week:20180723", Stats::Common::PERMANENT_EXP_GRN_IDX[:week], Time.parse("20180723").utc.to_i]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                  end
                end
                
                context 'month granularity is correctly generated' do
                  it 'with simple values' do
                    limits = get_limits(Stats::Common::PERMANENT_EXP_GRN_IDX[:month], Time.parse("2018091015").utc.to_i, Stats::Common::PERMANENT_EXP_GRN_IDX[:month], Time.parse("2018112512").utc.to_i)
                    time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
                    expected_results = [
                      ["month:20180901", Stats::Common::PERMANENT_EXP_GRN_IDX[:month], Time.parse("20180901").utc.to_i],
                      ["month:20181001", Stats::Common::PERMANENT_EXP_GRN_IDX[:month], Time.parse("20181001").utc.to_i],
                      ["month:20181101", Stats::Common::PERMANENT_EXP_GRN_IDX[:month], Time.parse("20181101").utc.to_i]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                  end
                end
                
                context 'year granularity is correctly generated' do
                  let(:service_context) do
                    ServiceContext.new.tap do |svc|
                      svc.from = Time.parse("2016072810").to_i
                      svc.to = Time.parse("2022072811").to_i
                    end
                  end
                  
                  it 'with simple values' do
                    limits = get_limits(Stats::Common::PERMANENT_EXP_GRN_IDX[:year], Time.parse("2018091015").utc.to_i, Stats::Common::PERMANENT_EXP_GRN_IDX[:year], Time.parse("2020112512").utc.to_i )
                    time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
                    expected_results = [
                      ["year:20180101", Stats::Common::PERMANENT_EXP_GRN_IDX[:year], Time.parse("20180101").utc.to_i],
                      ["year:20190101", Stats::Common::PERMANENT_EXP_GRN_IDX[:year], Time.parse("20190101").utc.to_i],
                      ["year:20200101", Stats::Common::PERMANENT_EXP_GRN_IDX[:year], Time.parse("20200101").utc.to_i]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                  end
                end
                
                context 'eternity granularity is correctly generated' do
                  it 'with simple values' do
                    limits = get_limits(Stats::Common::PERMANENT_EXP_GRN_IDX[:eternity], nil, nil, nil)
                    time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
                    expected_results = [
                      ["eternity", Stats::Common::PERMANENT_EXP_GRN_IDX[:eternity]]
                    ]
                    results = []
                    time_gen.each { |r| results << r }
                    expect(results).to eq expected_results
                  end         
                end
              end
              
              context 'when metric_type parameter is "user"' do
                let (:metric_type) { :user }
                context 'and limits parameter is nil' do
                  let(:limits) { nil }
                  it 'returns keys containing all the defined types of granularities' do
                    time_gen = Timestamp.get_time_generator(service_context, limits, metric_type)
                    gen_grn = get_granularities_from_generator(time_gen)
                    svc_grn = get_permanent_expanded_granularities
                    expect(gen_grn).to eq svc_grn
                  end
                end
                
                context 'and limits parameter is not nil' do
                  
                end
              end
            end
          end
        end
      end
    end
  end
end