require '3scale/backend/listener_metrics'

module ThreeScale
  module Backend
    module Rack
      describe Prometheus do
        describe '.call' do
          let(:app) { double }
          let(:error) { RuntimeError.new('Internal error') }
          let(:req_env) { { 'REQUEST_PATH' => '/' } }

          context 'when there is an internal error' do
            before do
              expect(app).to receive(:call).and_raise(error)
              allow(ListenerMetrics).to receive(:report_resp_code)
              allow(ListenerMetrics).to receive(:report_response_time)
            end

            it 'reports a 500 error and the response time' do
              prometheus_middleware = Rack::Prometheus.new(app)

              expect { prometheus_middleware.call(req_env) }.to raise_error(error)
              expect(ListenerMetrics).to have_received(:report_resp_code)
                                     .with(req_env['REQUEST_PATH'], 500)
              expect(ListenerMetrics).to have_received(:report_response_time)
                                     .with(req_env['REQUEST_PATH'], satisfy { |v| v >= 0 })
            end
          end
        end
      end
    end
  end
end
