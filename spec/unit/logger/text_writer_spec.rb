module ThreeScale
  module Backend
    module Logging
      class Middleware
        describe TextWriter do
          let(:logger) { object_double(STDOUT) }
          subject { described_class.new(logger) }

          let(:fixed_fields_success_response) { 20 }
          let(:fixed_fields_error_response) { 13 }

          let(:lm) { SpecHelpers::LoglineMatcher.new }

          let(:rackrequest) { SpecHelpers::Rack::Request.new }
          let(:env) { rackrequest.env }
          let(:status) { 200 }
          let(:header) { '' }
          let(:began_at) { Time.now }

          # field_s provides a _string_ representing the Ruby code that would
          # return the field's value as a regexp string when "eval"-ed (the caller
          # must take care of escaping special characters if so desired).
          # This is so because RSpec tries to be super smart and kills
          # any attempt to pass in a callable or anything else that would
          # execute code referencing a let variable in the right context.
          shared_examples_for :field do |desc, position, log_type, field_s|
            it "writes out the #{desc} field" do
              expect(logger).to receive(:write).with(
                  lm.match_a_field(eval(field_s).to_s)).once

              log(log_type)
            end

            it "writes out the #{desc} field in the #{position} position" do
              expect(logger).to receive(:write).with(
                  lm.match_positional_field(eval(field_s).to_s,
                                            [position-1, position-1],
                                            [total_fields-position, total_fields-position])).once

              log(log_type)
            end
          end

          shared_examples_for :logline do |log_type|
            include_examples :field, 'HTTP method', 7, log_type, <<-'FIELD'
              '"' + rackrequest.http_method
            FIELD
            include_examples :field, 'path and query', 8, log_type, <<-'FIELD'
              Regexp.escape(rackrequest.path + (rackrequest.query_string.empty? ?
                '' : "?#{rackrequest.query_string}"))
            FIELD
            include_examples :field, 'HTTP version', 9, log_type, <<-'FIELD'
              Regexp.escape(rackrequest.env['HTTP_VERSION']) + '"'
            FIELD
            include_examples :field, 'status', 10, log_type, <<-'FIELD'
              status
            FIELD

            it 'writes out exactly the total number of fields expected' do
              expect(logger).to receive(:write).
                  with(lm.match_n_fields total_fields).once

              log(log_type)
            end
          end

          shared_examples_for 'successful response log' do
            let(:total_fields) { fixed_fields_success_response }

            it_behaves_like :logline, :success
          end

          shared_examples_for 'error response log' do
            let(:status) { 500 }
            let(:error_msg) { 'An error message' }
            let(:total_fields) do
              fixed_fields_error_response + error_msg.split.size
            end

            it 'writes out the exception message' do
              expect(logger).to receive(:write).with(
                  lm.match_a_field("\"#{error_msg}\"")).once
              log(:error)
            end

            it_behaves_like :logline, :error
          end

          shared_examples_for 'passing in extensions' do |log_type|
            let(:ext) { 'no_body=1&rejection_reason_header=0' }
            let(:ext_re) { Regexp.escape ext }
            let(:rackrequest) do
              SpecHelpers::Rack::Request.new(headers: { 'HTTP_3SCALE_OPTIONS' => ext })
            end

            it 'writes out the extensions header content' do
              expect(logger).to receive(:write).with(
                  lm.match_a_field("\"#{ext_re}\"")).once
              log(log_type)
            end

            it 'writes out the extensions header content in the last field' do
              expect(logger).to receive(:write).with(
                  lm.match_positional_field("\"#{ext_re}\"",
                                            [total_fields-1, total_fields-1],
                                            [0, 0])).once
              log(log_type)
            end
          end

          shared_examples_for 'not using extensions' do |log_type|
            # the request is not overwritten so the caller should set it up
            it 'writes a dash as the extensions header in the last field' do
              expect(logger).to receive(:write).with(
                  lm.match_positional_field('-',
                                            [total_fields-1, total_fields-1],
                                            [0, 0])).once
              log(log_type)
            end
          end

          describe '#log' do
            include_examples 'successful response log'

            context 'passing in extensions' do
              include_examples 'passing in extensions', :success

              it_behaves_like 'successful response log'
            end
          end

          describe '#log_error' do
            include_examples 'error response log'

            context 'passing in extensions' do
              include_examples 'passing in extensions', :error

              it_behaves_like 'error response log'
            end

            context 'not using extensions' do
              include_examples 'not using extensions', :error

              it_behaves_like 'error response log'
            end
          end

          private

          def log(type)
            if type == :success
              subject.log(env, status, header, began_at)
            elsif type == :error
              subject.log_error(env, status, error_msg, began_at)
            end
          end
        end
      end
    end
  end
end
