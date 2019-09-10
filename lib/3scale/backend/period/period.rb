# Periods model
#
# This is intended to be used instead of just symbols for identifying period
# granularities (month, day, etc) and specific time periods that belong to
# a granularity.
#
# The object hierarchy is:
#
# - Period: Ancestor Class
#
# Non-instanceable class, common ancestor of all classes.
#
# - Period::Month, Period::Year, etc: Period Granularity Classes
#
# Instanceable classes. They act as _values_ of class Period. That is, when you
# want to describe a "month" granularity, you can only use one object, the
# Period::Month class.
#
# - Period::Month#0x123, Period::Year#0x456, etc: Specific Period Instances
#
# These basically attach a timestamp and extra data (ie. start of the period) to
# a specific granularity.
#
# Inheritance
# ===========
#
# Period::Month#0x123 is a Period::Instance and a Period.
# Period::Month is a Period::Granularity and a Period.
#
# Ordering
# ========
#
# Ordering is available at both usable levels (Period::Month class, that is, the
# granularity, and Period::Month instance, that is the period).
# Both behave similarly: Period::Month#0x123 compares to other instances only
# when they have the same granularity, and then only with the start date.
# Granularity classes also have order from smaller to bigger granularities.
# That is: Period::Month < Period::Year is true, and Period::Month#0x123 <
# Period::Month#0x456 is true if the first starts before.
#
# Representation
# ==============
#
# Both granularity classes and period instances represent themselves in String
# (to_s) and JSON (as_json) with the granularity name as a convenience. Be
# careful when you #to_s a period instance, since you'll only get the
# granularity name!
#
# The instance can also represent itself as a hash (to_hash), which includes all
# the relevant information (so it's not _just_ the granularity name, but also
# period start and finish). Again, the instance uses the granularity to
# represent itself as String/JSON, not the start/finish/timestamp data.
#
# Notes
# =====
#
# Period instances have a start and a finish because Ruby cannot call directly
# a method named "end".
#
# Usage
# =====
#
# You use either "Period(:month)" or "Period[:month]" to refer to the
# Period::Month singleton class, which is a Period::Granularity.
# You use either "Period(:month, Time.now.utc)" or "Period[:month,
# Time.now.utc]" to create an instance of the Period::Month class, which you can
# later call useful methods on such as #start and #finish (which are always
# cached), and is a Period::Instance.
# You can build ranges with period granularities and period instances. And you
# can also break up a specific period into smaller ones, or ask it to create the
# list of siblings that would make up a bigger granularity.
#
module ThreeScale
  module Backend
    def self.Period(granularity, ts = nil)
      Period[granularity, ts]
    end

    module Period
      Unknown = Class.new StandardError do
        def initialize(granularity)
          super "unknown period granularity '#{granularity.inspect}'"
        end
      end

      # This describes how granularities break up into each other in descending
      # order and in absolute terms, that is, in discrete quantities. Most
      # notably, week and eternity don't build greater granularities (ie. you
      # cannot use absolute weeks to precisely define a month), but they can be
      # broken up into discrete smaller granularities, and second is not broken
      # up into smaller granularities, but can build bigger ones.
      #
      # Order is _meaningful_.
      LINKS = {
        second: {
          pred: nil,
          succ: :minute,
        },
        minute: {
          pred: :second,
          succ: :hour,
        },
        hour: {
          pred: :minute,
          succ: :day,
        },
        day: {
          pred: :hour,
          succ: :month,
        },
        week: {
          pred: :day,
          succ: nil,
        },
        month: {
          pred: :day,
          succ: :year,
        },
        year: {
          pred: :month,
          succ: :eternity,
        },
        eternity: {
          pred: :year,
          succ: nil,
        }
      }.freeze
      private_constant :LINKS

      SYMBOLS = LINKS.keys.freeze
      SYMBOLS_DESC = SYMBOLS.reverse.freeze

      # shared helpers
      module HelperMethods
        # returns nil if not found
        def get_granularity_class(granularity)
          HASH.fetch granularity do
            if granularity.is_a? Granularity
              granularity
            else
              nil
            end
          end
        end
        private :get_granularity_class
      end
      private_constant :HelperMethods

      # Marker modules - they allow includers to be queried with #is_a? and
      # synonyms. Period is also a marker module, and it contains no instance
      # methods.
      module Instance
        include Period
      end

      # Marker module with methods applying to granularities
      module Granularity
        include Period

        def self.included(base)
          base.include Methods
        end

        # We want to share these methods between granularity classes.
        module Methods
          include HelperMethods
          include Comparable

          def <=>(other)
            other = get_granularity_class other
            return nil if other.nil?
            # avoid using #== as this is just a pointer comparison - much like
            # comparing object ids.
            if self.equal? other
              0
            elsif ALL.index(self) < ALL.index(other)
              -1
            else
              1
            end
          end
        end
        private_constant :Methods
      end

      # Period class methods
      module ClassMethods
        include Enumerable

        def each(&blk)
          ALL.each(&blk)
        end

        def from(granularity, ts = nil)
          klass = get_granularity_class granularity
          raise Unknown, granularity if klass.nil?
          ts ? klass.new(ts) : klass
        end

        def instance_periods_for_ts(timestamp)
          Hash.new { |hash, period| hash[period] = period.new(timestamp) }
        end

        alias_method :[], :from

        include HelperMethods
      end
      private_constant :ClassMethods

      class << self
        # We want to override Module#<=> because we have different semantics:
        # we use :<=> for granularity order (vs whether a module contains
        # another one in the default Module method). This is the Period module,
        # but leaving this public could lead to confusion:
        #
        # Period < Period::Month
        #
        # would return a boolean, and make users think there is an ordering
        # relation wrt granularities, which is non-sensical. So we are going to
        # make them private, and if you ever need them you can still use "send".
        private :<=>, *Comparable.instance_methods.select { |m| respond_to? m, true }

        include ClassMethods

        private

        # creates a class for a specific period granularity
        def create_granularity_class(name)
          Class.new do
            include Instance

            @name = name
            @to_s = name.to_s

            define_singleton_method :start, &Boundary.get_callable(name, :start)
            define_singleton_method :finish, &Boundary.get_callable(name, :finish)

            class << self
              include Granularity

              attr_reader :name, :to_s

              alias_method :to_sym, :name

              alias_method :from, :new
              alias_method :[], :new

              # JSON conversion required by ActiveSupport
              def as_json(_options = nil)
                to_s
              end

              def remaining(ts = Time.now.utc)
                finish(ts) - ts
              end

              # methods useful to construct ranges
              def succ
                granularity = LINKS[name][:succ]
                Period[granularity] if granularity
              end

              def pred
                granularity = LINKS[name][:pred]
                Period[granularity] if granularity
              end

              def new(timestamp = Time.now)
                timestamp = timestamp.utc
                cached = Period::Cache.get name, start(timestamp)
                if cached
                  # cache hit
                  cached
                else
                  # cache miss
                  obj = super timestamp
                  Period::Cache.set name, obj
                  obj
                end
              end
            end

            # instance methods
            attr_reader :granularity, :timestamp, :start, :finish

            def initialize(timestamp)
              @granularity = self.class
              @timestamp = timestamp
              @start = granularity.start(self.timestamp)
              @finish = granularity.finish(self.timestamp)
            end

            # These are convenience methods to let us print directly the
            # granularity of this period _instead of_ the full data including
            # the "compact" representation of the start date. This is so to
            # avoid having to change many users at this stage, but can be
            # confusing as it makes string representation of the instance the
            # same as the one from the granularity.
            def to_s
              granularity.to_s
            end

            def to_sym
              granularity.to_sym
            end

            def to_hash
              {
                granularity: to_s,
                start: start,
                finish: finish,
              }
            end
            alias_method :to_h, :to_hash

            # always define this to prevent ActiveSupport from "discovering" the
            # wrong methods for JSON-ification, ie. #each and/or #to_h(ash).
            def as_json(options = nil)
              granularity.as_json(options)
            end

            # Comparing two specific period instances only works if they refer
            # to the same granularity and the same specific period range. It
            # does not matter whether their timestamp is different.
            include Comparable

            def <=>(o)
              case o
              when Symbol, Granularity
                granularity <=> o
              when Instance
                start <=> o.start if granularity == o.granularity
              else
                nil
              end
            end

            # case equality - whether a timestamp is included
            def ===(ts)
              ts >= start && ts < finish
            end

            # break this period down into smaller ones
            def break_down(&blk)
              klass = granularity.pred
              iter = if klass.nil?
                       []
                     else
                       klass.new(start)..klass.new(finish - 1)
                     end
              iter.each(&blk)
            end

            # get the list of periods contained by the enclosing period
            def build_up(&blk)
              klass = granularity.succ
              iter = if klass.nil?
                       []
                     else
                       # #each calls break_down
                       klass.new(start)
                     end
              iter.each(&blk)
            end

            # Enumerable is not being included because some external code
            # actually thinks of this as a collection that must be listed
            # instead of just inspecting or printing its value (this is the
            # case with RSpec and ActiveSupport at least).
            alias_method :each, :break_down

            def remaining(ts)
              finish - ts
            end

            # Range period iteration
            def succ
              self.class.new(finish)
            end

            def pred
              self.class.new(start - 1)
            end
          end
        end
      end

      # All period granularities, sorted asc by duration (as defined in SYMBOLS)
      ALL = SYMBOLS.map do |p|
        name = p.capitalize
        # create Period::Month()
        define_singleton_method name do |*args|
          Period.from p, *args
        end
        const_set(name, create_granularity_class(p).freeze)
      end.freeze
      ALL_DESC = ALL.reverse.freeze

      HASH = Hash[SYMBOLS.zip ALL].freeze
    end
  end
end
