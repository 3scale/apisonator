module ThreeScale
  module Backend
    class Logger
      describe Middleware do
        def run_request
          if app.status == 500
            expect { rackrequest.run(subject) }.
              to raise_error(SpecHelpers::Rack::App::Error)
          else
            rackrequest.run(subject)
          end
        end

        let(:app) { SpecHelpers::Rack::App.new }
        let(:lm) { SpecHelpers::LoglineMatcher.new }
        let(:rackrequest) { SpecHelpers::Rack::Request.new }
        let(:logger) { object_double(STDOUT) }
        let(:fixed_fields_success_response) { 19 }
        let(:fixed_fields_error_response) { 12 }
        subject { described_class.new(app.app, logger) }

        # field_s provides a _string_ representing the Ruby code that would
        # return the field's value as a regexp string when "eval"-ed (the caller
        # must take care of escaping special characters if so desired).
        # This is so because RSpec tries to be super smart and kills
        # any attempt to pass in a callable or anything else that would
        # execute code referencing a let variable in the right context.
        shared_examples_for :field do |desc, position, field_s|
          it "writes out the #{desc} field" do
            expect(logger).to receive(:write).with(
              lm.match_a_field(eval(field_s).to_s)).once
            run_request
          end

          it "writes out the #{desc} field in the #{position} position" do
            expect(logger).to receive(:write).with(
              lm.match_positional_field(eval(field_s).to_s,
              [position-1, position-1],
              [total_fields-position, total_fields-position])).once
            run_request
          end
        end

        shared_examples_for :logline do
          include_examples :field, 'HTTP method', 7, <<-'FIELD'
            '"' + rackrequest.http_method
          FIELD
          include_examples :field, 'path and query', 8, <<-'FIELD'
            Regexp.escape(rackrequest.path + (rackrequest.query_string.empty? ?
              '' : "?#{rackrequest.query_string}"))
          FIELD
          include_examples :field, 'HTTP version', 9, <<-'FIELD'
            Regexp.escape(rackrequest.env['HTTP_VERSION']) + '"'
          FIELD
          include_examples :field, 'status', 10, <<-'FIELD'
            app.status
          FIELD

          it "writes out exactly the total number of fields expected" do
            expect(logger).to receive(:write).
              with(lm.match_n_fields total_fields).once
            run_request
          end
        end

        shared_examples_for 'successful response' do
          let(:total_fields) { fixed_fields_success_response }

          it_behaves_like :logline
        end

        shared_examples_for 'error response' do
          let(:app) { SpecHelpers::Rack::App.new(status: 500, failure: true) }
          let(:total_fields) do
            fixed_fields_error_response + app.exception.message.split.size
          end

          it 'writes out the exception message' do
            expect(logger).to receive(:write).with(
              lm.match_a_field("\"#{app.exception.message}\"")).once
            run_request
          end

          it_behaves_like :logline
        end

        context 'when logging a successful response' do
          include_examples 'successful response'
        end

        context 'when logging an error response' do
          include_examples 'error response'
        end
      end
    end
  end
end
