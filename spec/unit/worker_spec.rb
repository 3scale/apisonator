module ThreeScale
  module Backend
    describe Worker do
      # It is a private method, I know, but it was causing an important bug
      # (workers crashing when decoding non-utf8 arguments for jobs), so it
      # makes sense to test it.
      describe '#reserve' do
        subject { Worker.new(one_off: true) }

        let(:resque_queue) { 'queue:priority' }
        let(:job_queue) { resque_queue.sub('queue:', '') }

        context 'when the arguments of the job do not have encoding issues' do
          let(:enqueued_job) do
            { 'class' => 'ThreeScale::Backend::Transactor::ReportJob',
              'args' => ['100',
                         { '0' => { 'app_id' => '123', 'usage' => { 'hits' => 1 } } },
                         1455783230,
                         { }] }
          end

          let(:job_info) { [resque_queue, subject.encode(enqueued_job)] }

          before do
            allow(subject.redis).to receive(:blpop).and_return(job_info)
          end

          it 'returns a job with the correct resque queue and payload' do
            job = subject.send(:reserve)
            expect(job.queue).to eq job_queue
            expect(job.payload).to eq enqueued_job
          end
        end

        context 'when the arguments of the job contain invalid UTF8 characters' do
          let(:enqueued_job) do
            "{\"class\":\"ThreeScale::Backend::Transactor::ReportJob\","\
            "\"args\":[\"100\",{\"0\":{\"app_id\":\"123\",\"usage\":{\"hits\":1}}},"\
            "1455783230,{\"log\":\"\xF0\x90\x28\xBC\"}]}"
          end

          let(:job_info) { [resque_queue, enqueued_job] }

          before do
            allow(subject.redis).to receive(:blpop).and_return(job_info)
          end

          it 'returns a job with the correct resque queue and payload' do
            job = subject.send(:reserve)
            expect(job.queue).to eq job_queue
            expect(job.payload).to eq JSON.parse(enqueued_job)
          end

          it 'does not replace the invalid chars of the job payload' do
            expect(subject.send(:reserve).payload.valid_encoding?).to be false
          end
        end

        context 'when the object we get from Resque queue is nil' do
          before { allow(subject.redis).to receive(:blpop).and_return(nil) }

          it 'returns nil' do
            expect(subject.send(:reserve)).to be nil
          end
        end

        context 'when the object we get from the Resque queue is empty' do
          before { allow(subject.redis).to receive(:blpop).and_return([]) }

          it 'returns nil' do
            expect(subject.send(:reserve)).to be nil
          end
        end

        context 'when the object we get from the Resque queue is not a well-formed JSON' do
          let(:invalid_enqueued_job) { [resque_queue, '{}}'] }

          before do
            allow(subject.redis).to receive(:blpop).and_return(invalid_enqueued_job)
            allow(described_class.logger).to receive(:notify)
          end

          it 'returns nil' do
            expect(subject.send(:reserve)).to be nil
          end

          it 'notifies the logger' do
            expect(described_class.logger).to receive(:notify)
            subject.send :reserve
          end
        end
      end
    end
  end
end
