module ThreeScale
  module Backend
    class Memoizer

      EXPIRE = 60
      PURGE = 60
      MAX_ENTRIES = 10000
      ACTIVE = true

      # Initialize the class variables
      # XXX Note: using class variables is generally bad practice,
      # we might want to clean this up in the future
      @@memoizer_cache = Hash.new
      @@memoizer_cache_expires = Hash.new
      @@memoizer_purge_time = nil
      @@memoizer_stats_count = 0
      @@memoizer_stats_hits = 0

      # Key management:
      #
      # When automatically memoizing using the decorator, you should
      # NEVER assume a specific key format. Here are some helpers to
      # let you build keys to clear or getting them.
      #
      # You should only use build_keys_for_class and build_key
      #

      private

      def self.build_class_key(klass)
        classkey = klass.to_s
        # This can receive both objects and classes, so check if we can
        # call singleton_class? before actually doing so.
        if klass.respond_to? :singleton_class? and klass.singleton_class?
          # obtain class from Ruby's metaclass notation
          classkey = classkey.split(':').delete_if do |k|
            k[0] == '#'
          end.join(':').split('>').first
        else
          classkey
        end
      end

      def self.build_method_key(classkey, methodname)
        classkey + '.' + methodname
      end

      def self.build_args_key(methodkey, *args)
        if args.empty?
          methodkey
        else
          methodkey + '-' + args.join('-')
        end
      end

      public

      # Generate a key for the given class, method and args
      def self.build_key(klass, method, *args)
        key = build_class_key klass
        key = build_method_key key, method.to_s
        build_args_key key, *args
      end

      # Pass in the class or object that receives the memoized
      # methods, and a hash containing the methods as keys and
      # an array of their arguments in order.
      def self.build_keys_for_class(klass, methods_n_args)
        classkey = build_class_key klass
        methods_n_args.map do |method, args|
          key = build_method_key(classkey, method.to_s)
          build_args_key key, *args
        end
      end

      def self.reset!
        @@memoizer_cache = Hash.new
        @@memoizer_cache_expires = Hash.new
        @@memoizer_purge_time = nil
        @@memoizer_stats_count = 0
        @@memoizer_stats_hits = 0
      end

      def self.memoized?(key)
        return false unless ACTIVE
        @@memoizer_cache ||= Hash.new
        @@memoizer_cache_expires ||= Hash.new

        now = Time.now.getutc.to_i
        @@memoizer_purge_time ||= now

        is_memoized = (@@memoizer_cache.has_key?(key) && @@memoizer_cache_expires.has_key?(key) && (now - @@memoizer_cache_expires[key]) < EXPIRE)
        purge(now) if (@@memoizer_purge_time.nil? || (now - @@memoizer_purge_time) > PURGE)

        @@memoizer_stats_count ||= 0
        @@memoizer_stats_hits ||= 0

        @@memoizer_stats_count = @@memoizer_stats_count + 1
        @@memoizer_stats_hits = @@memoizer_stats_hits + 1 if is_memoized

        return is_memoized
      end

      def self.memoize(key, obj)
        return obj unless ACTIVE
        @@memoizer_cache ||= Hash.new
        @@memoizer_cache_expires ||= Hash.new
        @@memoizer_cache[key] = obj
        @@memoizer_cache_expires[key] = Time.now.getutc.to_i
        obj
      end

      def self.get(key)
        @@memoizer_cache[key]
      end

      def self.clear(keys)
        Array(keys).each do |key|
          @@memoizer_cache_expires.delete key
          @@memoizer_cache.delete key
        end
      end

      def self.purge(time)
        ## not thread safe
        @@memoizer_purge_time = time

        @@memoizer_cache_expires.each do |key, inserted_at|
          if (time - inserted_at > EXPIRE)
            @@memoizer_cache_expires.delete(key)
            @@memoizer_cache.delete(key)
          end
        end

        ##safety, should never reach this unless massive concurrency
        reset! if @@memoizer_cache_expires.size > MAX_ENTRIES
      end

      def self.stats
        @@memoizer_cache ||= Hash.new
        @@memoizer_cache_expires ||= Hash.new
        {:size => @@memoizer_cache.size, :count => (@@memoizer_stats_count || 0), :hits => (@@memoizer_stats_hits || 0)}
      end

      def self.memoize_block(key, &block)
        if !memoized?(key)
          obj = yield
          Memoizer.memoize(key, obj)
        else
          Memoizer.get(key)
        end
      end

      # Decorator allows a class or module to include it and get
      #   memoize :method1, :method2, ...
      # using keys "#{classname}.#{methodname}-#{arg1}-#{arg2}-..."
      module Decorator
        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          def memoize_instance_method(m)
            method_name = m.name
            define_method(method_name) do |*args|
              key = Memoizer.build_method_key self.to_s, method_name.to_s
              key = Memoizer.build_args_key key, *args
              Memoizer.memoize_block(key) do
                m.bind(self).call(*args)
              end
            end
          end
          private :memoize_instance_method

          def memoize_bindable_class_method(m, partialkey)
            define_method(m.name) do |*args|
              key = Memoizer.build_args_key partialkey, *args
              Memoizer.memoize_block(key) do
                m.bind(self).call(*args)
              end
            end
          end
          private :memoize_bindable_class_method

          def memoize_class_method(m, partialkey)
            define_singleton_method(m.name) do |*args|
              key = Memoizer.build_args_key partialkey, *args
              Memoizer.memoize_block(key) do
                m.call(*args)
              end
            end
          end
          private :memoize_class_method

          # memoize :method, :other_method, ...
          #
          # Decorate the methods passed in memoizing their results based
          # on the parameters they receive using a key with the form:
          # (ClassName|Instance).methodname[-param1[-param2[-...]]]
          #
          # You can call this from a class on instance or class methods, and
          # from a metaclass on instance methods, which actually are class
          # methods.
          #
          # CAVEAT: if you have an instance method named exactly as an existing
          # class method you either memoize the instance method BEFORE defining
          # the class method or use memoize_i on the instance method.
          #
          # WARNING: do NOT memoize instance methods of a class or call memoize
          # from a metaclass context if the methods are going to be called a
          # huge number of times, because you will be incurring in a binding
          # overhead that is noticeable for highly called methods.
          #
          def memoize(*methods)
            classkey = Memoizer.build_class_key self
            methods.each do |m|
              # For each method, first search for a class method, which is the
              # common case. If not found, then look for an instance method.
              #
              begin
                key = Memoizer.build_method_key(classkey, m.to_s)
                if singleton_class?
                  original_method = instance_method m
                  raise NameError unless original_method.owner == self
                  memoize_bindable_class_method original_method, key
                else
                  original_method = method m
                  raise NameError unless original_method.owner == self.singleton_class
                  memoize_class_method original_method, key
                end
              rescue NameError
                # If we cannot find a class method, try an instance method
                # before bailing out.
                memoize_i m
              end
            end
          end

          # memoize_i :method, :other_method
          #
          # Forces memoization of methods which are instance methods in
          # the current context level. This can be used to, for example,
          # override the default look up when we have two methods, class
          # and instance, which are named the same and we want to memoize
          # both or only the instance level one.
          def memoize_i(*methods)
            methods.each do |m|
              # We don't support calling this from a metaclass, because
              # we have not built a correct key. The user should use memoize
              # instead of this, which will already work with the instance
              # methods within a metaclass, that is, the class' class methods.
              raise NameError if singleton_class?
              original_method = instance_method m
              raise NameError unless original_method.owner == self
              memoize_instance_method original_method
            end
          end
        end

      end
    end
  end
end
