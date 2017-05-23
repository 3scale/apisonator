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

          it "can be instantiated" do
            expect(subject).to respond_to(:new)
          end

          context "instance" do
            let(:time) { Time.now.utc }
            subject { klass.new(time) }

            include_examples "representable as", "Symbol", :to_sym, granularity.to_sym
            include_examples "representable as", "string", :to_s, granularity.to_s
            include_examples "representable as", "JSON", :as_json, granularity.as_json

            [Period, Period::Instance].each do |parent_mod|
              it "is a #{parent_mod.name}" do
                expect(subject).to be_a(parent_mod)
              end
            end

            it "refers back to its granularity class" do
              expect(subject.granularity).to be(klass)
            end

            # XXX TODO comparison, succ/pred, start/finish, etc
          end
        end
      end
    end
  end
end
