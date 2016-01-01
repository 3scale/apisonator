require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module Transactor
      describe LogRequestJob do
        include TestHelpers::Sequences

        describe 'parameter conversion' do
          before do
            LogRequestCubertStorage.stub :store_all
            ThreeScale::Backend::Worker.new
          end

          it 'changes :usage to a string' do
            LogRequestStorage.should_receive(:store_all).with(any_args) do |args|
              args.first[:usage].should == "hits: 1, other: 6, "
            end

            LogRequestJob.perform(1, [usage: {'hits' => 1, 'other' => 6}, log: {}],
              Time.now.getutc.to_f)
          end

          it 'changes missing fields to "N/A"' do
            LogRequestStorage.should_receive(:store_all).with(any_args) do |args|
              args.first[:usage].should == "N/A"
              args.first[:log]['code'].should == "N/A"
              args.first[:log]['request'].should == "N/A"
              args.first[:log]['response'].should == "N/A"
            end

            LogRequestJob.perform(1, [log: {}], Time.now.getutc.to_f)
          end

          it 'passes non-empty data' do
            LogRequestStorage.should_receive(:store_all).with(any_args) do |args|
              args.first[:usage].should == "N/A"
              args.first[:log]['code'].should == '200'
              args.first[:log]['request'].should == "/request?bla=bla&"
              args.first[:log]['response'].should == "<xml>response</xml>"
            end

            LogRequestJob.perform(1, [log: {'request' => '/request?bla=bla&',
              'code' => '200', 'response' => '<xml>response</xml>'}],
              Time.now.getutc.to_f)
          end

          it 'truncates fields that are too long' do
            long_request = (0...LogRequestStorage::ENTRY_MAX_LEN_REQUEST+100).
              map{ ('a'..'z').to_a[rand(26)] }.join
            long_response = (0...LogRequestStorage::ENTRY_MAX_LEN_RESPONSE+100).
              map{ ('a'..'z').to_a[rand(26)] }.join
            long_code = (0...LogRequestStorage::ENTRY_MAX_LEN_CODE+100).
              map{ ('a'..'z').to_a[rand(26)] }.join
            LogRequestStorage.should_receive(:store_all).with(any_args) do |args|
              args.first[:usage].should == "N/A"
              args.first[:log]['code'].should =~ /#{LogRequestStorage::TRUNCATED}/
              args.first[:log]['request'].should =~ /#{LogRequestStorage::TRUNCATED}/
              args.first[:log]['response'].should =~ /#{LogRequestStorage::TRUNCATED}/
              args.first[:log]['code'].length.should be < long_code.length
              args.first[:log]['request'].length.should be < long_request.length
              args.first[:log]['response'].length.should be < long_response.length
            end

            LogRequestJob.perform(1, [log: {'request' => long_request,
              'code' => long_code, 'response' => long_response}],
              Time.now.getutc.to_f)
          end
        end

      end
    end
  end
end

