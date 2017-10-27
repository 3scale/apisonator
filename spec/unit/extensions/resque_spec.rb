require_relative '../../spec_helper'

module ThreeScale
  module Backend
    describe ResqueHacks do
      subject { Class.new.extend(described_class) }

      let(:test_hooks) do
        { before_hooks: [:before_perform_2, :before_perform_1],
          around_hooks: [:around_perform_2, :around_perform_1],
          after_hooks: [:after_perform_2, :after_perform_1],
          failure_hooks: [:on_failure_1, :on_failure_2],
          after_enqueue_hooks: [:after_enqueue_1, :after_enqueue_2],
          before_enqueue_hooks: [:before_enqueue_1, :before_enqueue_2],
          after_dequeue_hooks: [:after_dequeue_2, :after_dequeue_1],
          before_dequeue_hooks: [:before_dequeue_2, :before_dequeue_1] }
      end

      let(:test_class) do
        class ResqueHacksTest
          def i_am_not_a_hook; end
        end

        test_hooks.values.flatten.each do |hook|
          ResqueHacksTest.singleton_class.send(:define_method, hook) {}
        end

        ResqueHacksTest
      end

      [{ method: :before_hooks, prefix: 'before_perform' },
       { method: :around_hooks, prefix: 'around_perform' },
       { method: :after_hooks, prefix: 'after_perform' },
       { method: :failure_hooks, prefix: 'on_failure' },
       { method: :after_enqueue_hooks, prefix: 'after_enqueue' }].each do |hook|
        describe ".#{hook[:method]}" do
          let(:hooks) { test_hooks[hook[:method]] }

          it "returns the methods that start with '#{hook[:prefix]}' sorted" do
            expect(subject.send(hook[:method], test_class)).to eq hooks.sort
          end
        end
      end
    end
  end
end
