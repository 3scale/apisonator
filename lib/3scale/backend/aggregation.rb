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
        rules.aggregate(transaction)
      end
      
      # Makes sure that 1.day is the same as :day and so on.
      def self.normalize_granularity(granularity)
        case granularity
        when 1.week                                   then :week
        when 1.day                                    then :day
        when 1.hour                                   then :hour
        when 1.minute                                 then :minute
        when 1.second                                 then :second
        when Symbol, Integer, ActiveSupport::Duration then granularity
        when /\d+/                                    then granularity.to_i
        else granularity.to_sym
        end
      end
    end
  end
end
