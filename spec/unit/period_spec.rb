module ThreeScale
  module Backend
    # Period() class method
    describe '#Period' do
      context 'with a granularity argument' do
        subject { ThreeScale::Backend.Period(:month) }

        it { is_expected.to be(Period::Granularity::Month) }

        context 'and a timestamp argument' do
          subject { ThreeScale::Backend.Period(:month, Time.now) }

          it { is_expected.to be_a(Period::Instance) }

          it 'refers to the correct granularity' do
            expect(subject.granularity).to be(Period::Granularity::Month)
          end
        end

        context 'and a non-timestamp argument' do
          it 'raises an error' do
            expect do
              ThreeScale::Backend.Period(:month, :something_else)
            end.to raise_error(NoMethodError)
          end
        end
      end

      context 'with a non-granularity argument' do
        it 'raises a Period::Unknown error' do
          expect do
            ThreeScale::Backend.Period(:something_else)
          end.to raise_error(Period::Unknown)
        end
      end
    end

    describe Period do
      WELL_KNOWN_GRANULARITIES = [:minute, :hour, :day, :week, :month, :year, :eternity]

      subject { Period }

      it 'can iterate through all the Period::Granularity classes' do
        res = subject.each.entries
        expect(res.all? { |e| e.is_a?(Period::Granularity) }).to be true
        expect(res.map(&:to_sym)).to include *WELL_KNOWN_GRANULARITIES
      end

      it 'defines a SYMBOLS constant' do
        expect do
          described_class.const_get :SYMBOLS
        end.not_to raise_error
      end

      context 'SYMBOLS' do
        subject { described_class.const_get(:SYMBOLS) }

        it 'is a non-empty collection' do
          expect(subject).to_not be_empty
        end

        it 'is a set of unique elements' do
          expect(subject.uniq.size).to be(subject.size)
        end

        it 'is a set of symbols' do
          expect(subject).to all( be_a(Symbol) )
        end

        it 'is an ordered set of symbols when compared as Periods' do
          expect(subject.map do |granularity|
            Period[granularity]
          end.sort.map(&:to_sym)).to eq(subject)
        end

        context 'contains well-known granularities as symbols' do
          WELL_KNOWN_GRANULARITIES.each do |granularity|
            it "contains #{granularity}" do
              expect(subject).to include(granularity)
            end
          end
        end
      end

      context 'SYMBOLS_DESC' do
        subject { described_class.const_get(:SYMBOLS_DESC) }

        it 'is equal to SYMBOLS when reversed' do
          expect(subject.reverse).to eq(described_class.const_get(:SYMBOLS))
        end
      end

      context 'ALL' do
        subject { described_class.const_get(:ALL) }

        it 'is a non-empty collection' do
          expect(subject).to_not be_empty
        end

        it 'is a set of unique elements' do
          expect(subject.uniq.size).to be(subject.size)
        end

        it "is made up of Period::Granularities" do
          expect(subject).to all( be_a(Period::Granularity) )
        end

        it "contains the well known granularities as a subset" do
          expect(subject.map(&:to_sym)).to include(*WELL_KNOWN_GRANULARITIES)
        end
      end

      shared_examples_for "representable as" do |desc, meth, expected|
        context "#{meth}" do
          it "can be represented as #{desc}" do
            expect(subject).to respond_to(meth)
          end

          it "matches the expected representation" do
            expect(subject.send(meth)).to eq expected
          end
        end
      end

      described_class.const_get(:ALL).map(&:to_sym).each do |granularity|
        it "defines a constant with #{granularity}" do
          expect do
            described_class.const_get(granularity.capitalize)
          end.not_to raise_error
        end

        describe "::#{granularity.capitalize}" do
          let(:klass) { Period.const_get(granularity.capitalize) }
          subject { klass }

          include_examples "representable as", "Symbol", :to_sym, granularity.to_sym
          include_examples "representable as", "string", :to_s, granularity.to_s
          include_examples "representable as", "JSON", :as_json, granularity.as_json

          [Period, Period::Granularity].each do |parent_mod|
            it "is a #{parent_mod.name}" do
              expect(subject).to be_a(parent_mod)
            end
          end

          it "can be tested for equality with a symbol" do
            expect do
              subject == granularity
            end.not_to raise_error
          end

          it "matches the equivalent granularity symbol" do
            expect(subject == granularity).to be true
          end

          it "can be ordered relative to a granularity symbol" do
            expect do
              subject < granularity
            end.not_to raise_error
          end

          [:succ, :pred].each do |meth|
            it "responds to ##{meth}" do
              expect(subject).to respond_to(meth)
            end

            unless Period.const_get(granularity.capitalize).send(meth).nil?
              context "##{meth}" do
                subject { klass.send(meth) }

                it "returns a Period::Granularity" do
                  expect(subject).to be_a(Period::Granularity)
                end

                it "compares to the granularity symbol" do
                  expect do
                    subject < granularity
                  end.not_to raise_error
                end
              end
            end
          end

          it 'returns the time difference between a timestamp and its end of period' do
            timestamp = Time.now.utc
            end_period = Period::Boundary.get_callable(granularity, :finish)
                                         .call(timestamp)
            diff = end_period - timestamp

            expect(subject.remaining(timestamp)).to eq diff
          end

          it "can be instantiated" do
            expect(subject).to respond_to(:new)
          end

          context "instance" do
            let(:time) { Time.now.utc }
            subject { klass.new(time) }

            # To compare instances we need to add/subtract to time enough
            # seconds to jump to the next/previous period.
            # For seconds +1,-1 works, but not for the rest. For year, which
            # is the coarsest granularity that we use, we need at least
            # 60*60*24*366
            let(:greater) { klass.new(time + 60*60*24*366) }
            let(:same) { klass.new(time) }
            let(:less) { klass.new(time - 60*60*24*366) }

            let(:eternity_years) do
              Period::Boundary::Methods.const_get(:ETERNITY_FINISH).year -
                  Period::Boundary::Methods.const_get(:ETERNITY_START).year + 1
            end

            include_examples "representable as", "Symbol", :to_sym, granularity.to_sym
            include_examples "representable as", "string", :to_s, granularity.to_s
            include_examples "representable as", "JSON", :as_json, granularity.as_json

            [Period, Period::Instance].each do |parent_mod|
              it "is a #{parent_mod.name}" do
                expect(subject).to be_a(parent_mod)
              end
            end

            context '.new' do
              let(:start_time) do
                klass.start(time)
              end
              let(:next_time) do
                klass.finish(time)
              end

              # the specs below test for object identity with _equal_
              it 'returns a cached instance if available' do
                expect(klass.new start_time).to equal(klass.new(next_time - 1))
              end

              # this does not really work for eternity, since, well, you cannot
              # yet obtain the "next" eternity.
              it 'returns a new instance if no cache present' do
                # a different period, with different start time breaks the cache
                expect(klass.new start_time).not_to equal(klass.new next_time)
              end unless granularity == :eternity
            end

            it "refers back to its granularity class" do
              expect(subject.granularity).to be(klass)
            end

            it 'can be compared with other instances that refer to the same granularity' do
              # Eternity is a special case. Comparison between Eternity
              # instances always returns true.
              if granularity == :eternity
                expect(subject == greater).to be true
                expect(subject == same).to be true
                expect(subject == less).to be true
              else
                expect(subject < greater).to be true
                expect(subject == same).to be true
                expect(subject > less).to be true
              end
            end

            it 'defines case equality' do
              # Second is a special case because === only returns true with
              # another instance initialized with the same second.
              if granularity == :second
                expect(subject === subject.start).to be true
              else
                in_range = subject.start + 1
                out_of_range = subject.start - 1
                expect(subject === in_range).to be true
                expect(subject === out_of_range).to be false
              end
            end

            it 'has a start' do
              expect(subject.start).to eq Period::Boundary.start_of(granularity, time)
            end

            it 'has an end' do
              expect(subject.finish).to eq Period::Boundary.end_of(granularity, time)
            end

            it 'returns the remaining time until the end' do
              granularity_end = Period::Boundary.end_of(granularity, time)
              expected_remaining = granularity_end - time
              expect(subject.remaining(time)).to eq expected_remaining
            end

            it 'has a successor' do
              expect(subject.succ).to eq klass.new(subject.finish)
            end

            it 'has a predecessor' do
              expect(subject.pred).to eq klass.new(subject.start - 1)
            end

            it 'can get the list of periods contained by the enclosing one' do
              expected_elements = { second: 60,
                                    minute: 60,
                                    hour: 24,
                                    day: (28..31),
                                    week: 0,
                                    month: 12,
                                    year: eternity_years,
                                    eternity: 0 }

              res = subject.build_up.entries
              expected_size = expected_elements[granularity]

              if expected_size.is_a?(Numeric)
                expect(res.size).to eq expected_size
              else
                expect(expected_size).to include res.size
              end

              expect(res.all? do |period|
                period.granularity == klass
              end).to be true
            end

            it 'can be divided into instances of a more fine grained period' do
              expected_elements = { second: 0,
                                    minute: 60,
                                    hour: 60,
                                    day: 24,
                                    week: 7,
                                    month: (28..31),
                                    year: 12,
                                    eternity: eternity_years }

              res = subject.break_down.entries
              expected_size = expected_elements[granularity]

              if expected_size.is_a?(Numeric)
                expect(res.size).to eq expected_size
              else
                expect(expected_size).to include res.size
              end

              expect(res.all? do |period|
                period.granularity == klass.pred
              end).to be true
            end
          end
        end
      end
    end
  end
end
