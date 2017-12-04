raise "Memoizer is not thread safe" if ThreeScale::Backend::Manifest.thread_safe?

module ThreeScale
  module Backend
    class Memoizer
      EXPIRE = 60
      PURGE = 60
      MAX_ENTRIES = 10000
      ACTIVE = true
      private_constant :EXPIRE, :PURGE, :MAX_ENTRIES, :ACTIVE

      def self.reset!
        # Initialize class instance variables
        # Note: we would be better off pre-allocating the Hash size
        # ie. rb_hash_new_with_size(MAX_ENTRIES)
        @memoizer_cache = Hash.new
        @memoizer_purge_time = Time.now.getutc.to_i + PURGE
        @memoizer_stats_count = 0
        @memoizer_stats_hits = 0
      end

      reset!

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
          classkey.split(':'.freeze).delete_if do |k|
            k[0] == '#'.freeze
          end.join(':'.freeze).split('>'.freeze).first
        else
          classkey
        end
      end

      def self.build_method_key(classkey, methodname)
        classkey + '.'.freeze + methodname
      end

      def self.build_args_key(methodkey, *args)
        if args.empty?
          methodkey
        else
          methodkey + '-'.freeze + args.join('-'.freeze)
        end
      end

      # A method to inspect in debugging mode the contents of the cache
      def self.cache
        raise 'Memoizer.cache only in development!' unless ThreeScale::Backend.development?
        @memoizer_cache
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

      if ACTIVE
        Entry = Struct.new(:obj, :expire)
        private_constant :Entry

        def self.fetch(key)
          @memoizer_stats_count = @memoizer_stats_count + 1

          cached = @memoizer_cache[key]

          now = Time.now.getutc.to_i
          purge(now) if now > @memoizer_purge_time

          if cached && now <= cached.expire
            @memoizer_stats_hits = @memoizer_stats_hits + 1
            cached
          end
        end

        def self.memoize(key, obj)
          @memoizer_cache[key] = Entry.new(obj, Time.now.getutc.to_i + EXPIRE)
          obj
        end
      else
        def self.fetch(_key)
          nil
        end

        def self.memoize(_key, obj)
          obj
        end
      end

      def self.get(key)
        entry = @memoizer_cache[key]
        entry.obj if entry
      end

      def self.memoized?(key)
        !!(fetch key)
      end

      def self.clear(keys)
        Array(keys).each do |key|
          @memoizer_cache.delete key
        end
      end

      def self.purge(time)
        @memoizer_purge_time = time + PURGE

        @memoizer_cache.delete_if do |_, entry|
          time > entry.expire
        end

        ##safety, should never reach this unless massive concurrency
        reset! if @memoizer_cache.size > MAX_ENTRIES
      end

      def self.stats
        {
          size: @memoizer_cache.size,
          count: @memoizer_stats_count,
          hits: @memoizer_stats_hits,
        }
      end

      def self.memoize_block(key, &block)
        entry = fetch key
        if entry.nil?
          Memoizer.memoize(key, yield)
        else
          entry.obj
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
          module Helpers
            module_function

            def memoize_instance_method(m, klass)
              method_name = m.name
              method_s = method_name.to_s
              klass.send :define_method, method_name do |*args|
                key = Memoizer.build_method_key self.to_s, method_s
                key = Memoizer.build_args_key key, *args
                Memoizer.memoize_block(key) do
                  m.bind(self).call(*args)
                end
              end
            end
            private :memoize_instance_method

            def memoize_class_method(m, partialkey, klass)
              klass.define_singleton_method(m.name) do |*args|
                key = Memoizer.build_args_key partialkey, *args
                Memoizer.memoize_block(key) do
                  m.call(*args)
                end
              end
            end
            private :memoize_class_method

            # helper to go down one level from the current class context
            # ie. the reverse of singleton_class: from metaclass to class
            def get_instance_class(klass)
              return klass unless klass.singleton_class?
              # workaround Ruby's lack of the inverse of singleton_class
              base_s = klass.to_s.split(':').delete_if { |k| k.start_with? '#' }.
                join(':').split('>').first
              iklass = Kernel.const_get(base_s)
              # got the root class, now go up a level shy of self
              iklass = iklass.singleton_class while iklass.singleton_class != klass
              iklass
            end
            private :get_instance_class
          end

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
          # WARNING: do NOT use this memoize method on frequently called instance
          # methods since you'll have a noticeable overhead from the necessity
          # to bind the method to the object.
          #
          def memoize(*methods)
            classkey = Memoizer.build_class_key self
            # get the base class of self so that we get rid of metaclasses
            klass = Helpers.get_instance_class self
            # make sure klass points to the klass that self is a metaclass of
            # in case we're being invoked from a metaclass
            methods.each do |m|
              # For each method, first search for a class method, which is the
              # common case. If not found, then look for an instance method.
              #
              begin
                key = Memoizer.build_method_key(classkey, m.to_s)
                original_method = klass.method m
                raise NameError unless original_method.owner == klass.singleton_class
                Helpers.memoize_class_method original_method, key, klass
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
              Helpers.memoize_instance_method original_method, self
            end
          end
        end

      end
    end
  end
end
