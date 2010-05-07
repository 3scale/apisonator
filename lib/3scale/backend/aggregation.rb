require '3scale/backend/aggregation/rule'

module ThreeScale
  module Backend
    module Aggregation
      @@rules = []
      
      # Define aggregation rules in given block.
      #
      # Use like this:
      #
      #   Aggregation.define do |rules|
      #     rules.add :service, :granularity => 1.hour
      #     # ...
      #   end
      #
      def self.define
        yield self
      end
      
      def self.add(*args, &block)
        self.add_rule(Rule.new(*args, &block))
      end

      def self.add_rule(rule)
        @@rules << rule
      end
      
      # Run all defined aggregations with the given transactions.
      def self.aggregate(transaction)
        @@rules.each do |rule|
          rule.aggregate(transaction)
        end
      end
      
      # Makes sure that 1 day is the same as :day and so on.
      def self.normalize_granularity(granularity)
        case granularity
        when 7 * 24 * 60 * 60    then :week
        when     24 * 60 * 60    then :day
        when          60 * 60    then :hour
        when               60    then :minute
        when                1    then :second
        when Symbol, Integer     then granularity
        when /\d+/               then granularity.to_i
        else granularity.to_sym
        end
      end
    end
  end
end
