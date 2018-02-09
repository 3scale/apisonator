module ThreeScale
  module Backend
    module Logging
      class Middleware
        describe JsonWriter do
          let(:logger) { object_double(STDOUT) }
          subject { described_class.new(logger) }

          let(:now) { Time.now.getutc }
          let(:began_at) { now - 1.5}
          let(:date_format) { described_class.const_get(:DATE_FORMAT) }
          let(:memoizer_stats) { { size: 10, count: 20, hits: 15 } }
          let(:ext) { 'no_body=1&rejection_reason_header=0' }
          let(:ext_re) { Regexp.escape ext }

          let(:rackrequest) do
            SpecHelpers::Rack::Request.new(headers: { 'HTTP_3SCALE_OPTIONS' => ext })
          end
          let(:env) { rackrequest.env }
          let(:status) { 200 }
          let(:header) { '' }
          let(:query_string) do
            rackrequest.query_string.empty? ? '' : "?#{rackrequest.query_string}"
          end

          describe '#log' do
            # This test relies on the order of the fields of this hash which is
            # not 100% correct because a JSON has no order. To improve later.
            let(:expected_log) do
              { forwarded_for: '-',
                remote_user: '-',
                time: now.strftime(date_format),
                method: rackrequest.http_method,
                path_info: rackrequest.path,
                query_string: query_string,
                http_version: rackrequest.env['HTTP_VERSION'],
                status: status.to_s,
                response_time: now - began_at,
                request_id: '-',
                extensions: "\"#{ext_re}\"",
                length: '-',
                memoizer_size: memoizer_stats[:size],
                memoizer_count: memoizer_stats[:count],
                memoizer_hits: memoizer_stats[:hits] }
            end

            let(:expected_json) { expected_log.to_json + "\n" }

            before do
              allow(ThreeScale::Backend::Memoizer)
                  .to receive(:stats)
                  .and_return(memoizer_stats)
            end

            it 'writes the log with the expected format' do
              expect(logger).to receive(:write).with(expected_json).once
              Timecop.freeze(now) { subject.log(env, status, header, began_at) }
            end
          end

          describe '#log_error' do
            let(:error) { 'Some error message' }

            let(:expected_log) do
              { forwarded_for: '-',
                remote_user: '-',
                time: now.strftime(date_format),
                method: rackrequest.http_method,
                path_info: rackrequest.path,
                query_string: query_string,
                http_version: rackrequest.env['HTTP_VERSION'],
                status: status.to_s,
                response_time: now - began_at,
                request_id: '-',
                extensions: "\"#{ext_re}\"",
                error: error }
            end

            let(:expected_json) { expected_log.to_json + "\n" }

            it 'logs the error with the expected format' do
              expect(logger).to receive(:write).with(expected_json).once
              Timecop.freeze(now) { subject.log_error(env, status, error, began_at) }
            end
          end
        end
      end
    end
  end
end
