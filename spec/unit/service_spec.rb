require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe Service do

      describe '.load_id' do
        before { Service.save!(provider_key: 'foo', id: '7001') }

        it 'returns an ID' do
          Service.load_id('foo').should == '7001'
        end
      end

      describe '.load_by_id' do
        let(:service) do
          Service.save!(
            provider_key: 'foo', id: '7001', referrer_filters_required: 1
          )
        end
        let(:result){ Service.load_by_id(service.id) }

        it 'returns a Service object' do
          result.class.should == Service
        end

        it 'returns nil when ID not found' do
          Service.load_by_id('1234').should be_nil
        end

        it 'loads correct data' do
          result.provider_key.should == 'foo'
          result.id.should == '7001'
          result.backend_version.should be_nil
        end

        it 'changes filters_required field to a Boolean' do
          result.referrer_filters_required?.should be_true
        end

        describe 'user_registration_required' do
          it 'defaults to true when not set' do
            service = Service.save!(provider_key: 'foo', id: '7001')
            result = Service.load_by_id(service.id)

            result.user_registration_required?.should be_true
          end

          it 'changes to Boolean when set to Integer' do
            service = Service.save!(
              provider_key: 'foo', id: '7001', user_registration_required: 1)
            result = Service.load_by_id(service.id)

            result.user_registration_required?.should be_true
          end

          it 'is false when set to false' do
            service = Service.save!(provider_key: 'foo', id: '7001',
              user_registration_required: false, default_user_plan_id: '1001',
              default_user_plan_name: "user_plan_name")
            result = Service.load_by_id(service.id)

            result.user_registration_required?.should be_false
          end
        end
      end

    end
  end
end
