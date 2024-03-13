module ThreeScale
  module Backend
    module StorageAsync

      # This class accumulates commands and sends several of them in a single
      # request, instead of sending them one by one.
      class Pipeline
        include Methods

        Error = Class.new StandardError

        class PipelineSharedBetweenFibers < Error
          def initialize
            super 'several fibers are modifying the same Pipeline'
          end
        end

        # There are 2 groups of commands that need to be treated a bit
        # differently to follow the same interface as the redis-rb lib.
        # 1) The ones that need to return a bool when redis returns "1" or "0".
        # 2) The ones that need to return whether the result is greater than 0.

        CHECK_EQUALS_ONE = %w(EXISTS SISMEMBER).freeze
        private_constant :CHECK_EQUALS_ONE

        CHECK_GREATER_THAN_0 = %w(SADD SREM ZADD).freeze
        private_constant :CHECK_GREATER_THAN_0

        def initialize
          # Each command is an array where the first element is the name of the
          # command ('SET', 'GET', etc.) and the rest of elements are the
          # parameters for that command.
          # Ex: ['SET', 'some_key', 42].
          @commands = []

          # Save the ID of the fiber that created the Pipeline so later we
          # can check that this pipeline is not shared between fibers.
          @fiber_id = Fiber.current.object_id
        end

        # In the async-redis lib, all the commands are run with .call:
        # client.call('GET', 'a'), client.call('SET', 'b', '1'), etc.
        # This method just accumulates the commands and their params.
        def call(*args)
          if @fiber_id != Fiber.current.object_id
            raise PipelineSharedBetweenFibers
          end

          @commands << args

          # Some Redis commands in StorageAsync compare the result with 0.
          # For example, EXISTS. We return an integer so the comparison does
          # not raise an error. It does not matter which int, because here we
          # only care about adding the command to @commands.

          1
        end

        def pipelined(&block)
          # When running a nested pipeline, we just need to continue
          # accumulating commands.
          block.call self
        end

        # Send to redis all the accumulated commands.
        # Returns an array with the result for each command in the same order
        # that they added with .call().
        def run(redis_async_client)
          responses = collect_responses(redis_async_client)

          responses.zip(@commands).map do |resp, cmd|
            command_name = cmd.first.to_s.upcase

            if CHECK_EQUALS_ONE.include?(command_name)
              resp.to_i == 1
            elsif CHECK_GREATER_THAN_0.include?(command_name)
              resp.to_i > 0
            else
              resp
            end
          end
        end

        private

        def collect_responses(redis_async_client)
          async_pipe = redis_async_client.pipeline
          @commands.each do |command|
            async_pipe.write_request(*command)
          end

          # Redis returns an answer for each of the commands sent in the
          # pipeline. But in order to keep compatibility with redis-rb, here, if
          # there is an error in any of the commands of the pipeline we will
          # raise an error (the first one that occurred).

          first_err = nil

          res = @commands.size.times.map do
            begin
              async_pipe.read_response
            rescue ::Protocol::Redis::ServerError => e
              first_err ||= e
              nil
            end
          end

          raise first_err if first_err

          res
        ensure
          async_pipe.close
        end
      end
    end
  end
end
