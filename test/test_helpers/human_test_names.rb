module TestHelpers
  module HumanTestNames
    # Define tests using numan-readable names:
    #
    #   test 'human readable is cool!' do
    #     # ...
    #   end
    #
    # instead of:
    #
    #   def test_underscores_are_not_cool
    #     # ...
    #   end
    #
    def test(name, &block)
      name = "test: #{name}"

      defined = instance_method(name) rescue false
      raise "#{name} is already defined in #{self}" if defined

      define_method(name, &block)
    end
  end
end
