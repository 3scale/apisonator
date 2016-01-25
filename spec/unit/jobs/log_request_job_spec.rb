require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module Transactor
      describe LogRequestJob do
        include TestHelpers::Sequences

        describe 'parameter conversion' do
          let(:LogRequestCubertStorage) { class_double }

          before do
            allow(LogRequestCubertStorage).to receive(:store_all)
            ThreeScale::Backend::Worker.new
          end

          it 'changes :usage to a string' do
            expect(LogRequestStorage).to receive(:store_all).with(any_args) do |args|
              expect(args.first[:usage]).to eq "hits: 1, other: 6, "
            end

            LogRequestJob.perform(1, [usage: {'hits' => 1, 'other' => 6}, log: {}],
              Time.now.getutc.to_f)
          end

          it 'changes missing fields to "N/A"' do
            expect(LogRequestStorage).to receive(:store_all).with(any_args) do |args|
              expect(args.first[:usage]).to eq "N/A"
              expect(args.first[:log]['code']).to eq "N/A"
              expect(args.first[:log]['request']).to eq "N/A"
              expect(args.first[:log]['response']).to eq "N/A"
            end

            LogRequestJob.perform(1, [log: {}], Time.now.getutc.to_f)
          end

          it 'passes non-empty data' do
            expect(LogRequestStorage).to receive(:store_all).with(any_args) do |args|
              expect(args.first[:usage]).to eq "N/A"
              expect(args.first[:log]['code']).to eq '200'
              expect(args.first[:log]['request']).to eq "/request?bla=bla&"
              expect(args.first[:log]['response']).to eq "<xml>response</xml>"
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
            expect(LogRequestStorage).to receive(:store_all).with(any_args) do |args|
              expect(args.first[:usage]).to eq "N/A"
              expect(args.first[:log]['code']).to match /#{LogRequestStorage::TRUNCATED}/
              expect(args.first[:log]['request']).to match /#{LogRequestStorage::TRUNCATED}/
              expect(args.first[:log]['response']).to match /#{LogRequestStorage::TRUNCATED}/
              expect(args.first[:log]['code'].length).to be < long_code.length
              expect(args.first[:log]['request'].length).to be < long_request.length
              expect(args.first[:log]['response'].length).to be < long_response.length
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

