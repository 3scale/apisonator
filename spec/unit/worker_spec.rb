module ThreeScale
  module Backend
    describe Worker do

      # It is a private method, I know, but it was causing an important bug
      # (workers crashing when decoding non-utf8 arguments for jobs), so it
      # makes sense to test it.
      describe '#reserve' do
        subject { Worker.new(one_off: true) }

        let(:resque_queue) { 'queue_priority' } # Irrelevant for these tests

        context 'when the arguments of the job do not have encoding issues' do
          let(:enqueued_job) do
            { 'class' => 'ThreeScale::Backend::Transactor::ReportJob',
              'args' => ['100',
                         { '0' => { 'app_id' => '123', 'usage' => { 'hits' => 1 } } },
                         1455783230,
                         {  }] }
          end

          let(:job_info) { [resque_queue, subject.encode(enqueued_job)] }

          before do
            allow(subject.redis).to receive(:blpop).and_return(job_info)
          end

          it 'returns a job with the correct resque queue and payload' do
            job = subject.send(:reserve)
            expect(job.queue).to eq job_info.first
            expect(job.payload).to eq enqueued_job
          end
        end

        context 'when the arguments of the job contain non-valid UTF8 characters' do
          let(:enqueued_job) do
            { 'class' => 'ThreeScale::Backend::Transactor::ReportJob',
              'args' => ['100',
                         { '0' => { 'app_id' => '123', 'usage' => { 'hits' => 1 } } },
                         1455783230,
                         { 'log' => "\xf0\x90\x28\xbc" }] }
          end

          let(:job_info) { [resque_queue, subject.encode(enqueued_job)] }

          before do
            allow(subject.redis).to receive(:blpop).and_return(job_info)
          end

          it 'returns nil' do
            expect(subject.send(:reserve)).to be_nil
          end
        end
      end
    end
  end
end
