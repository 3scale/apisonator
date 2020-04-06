# ASYNC

- [Description](#description)
- [Goals](#goals)
- [Code](#code)
- [Limitations](#limitations)


## Description

Apisonator can be configured to use a non-blocking redis client. It's an opt-in
feature that can be enabled setting the `CONFIG_REDIS_ASYNC` env to `true`. When
the feature is enabled, Apisonator uses the
[async-redis](https://github.com/socketry/async-redis) client instead of
[redis-rb](https://github.com/redis/redis-rb).


## Goals

Using a non-blocking client should allow us to save resources. Also it makes it
easier to decide how to scale. With a blocking client it's difficult to decide
how many listeners/workers should be deployed per machine in order to use all
the available CPU. With a non-blocking client, in theory, a single process
should use a whole CPU when properly tuned.


## Code

We made a few changes in the codebase to support this feature. Here are the most
important ones:

- There are two worker classes. `WorkerAsync` and `WorkerSync`. `WorkerAsync`
needs to run a separate thread to fetch jobs from the queues. Apart from that,
they are pretty much the same.

- There's `Backend::StorageAsync::Client` and `Backend::StorageSync`.
`Backend::Storage` is now responsible for instantiating the correct type of
client based on the configuration.

- The majority of the code required to make async work is under
`lib/3scale/backend/storage_async`. That includes a wrapper for the
`async-redis` client, and some monkey-patching to optimize a few things. Some
tests helpers also needed to be adapted to choose between the two types of
clients.


## Limitations

- Any IO that does not use the async reactor is blocking. In practice, that
means that any gem except the ones in the [async group in
GitHub](https://github.com/socketry) is very likely to block.

- The whole test suite needs to be run both with the async client and the sync
one. The reason is that our tests are highly coupled with Redis, even the unit
ones. Running the test suite with only one of the clients is risky.

- Cannot use `Fiber.yield` in a lazy enumerator. See [ruby PR
2002](https://github.com/ruby/ruby/pull/2002). For example, an enumerator like
this does not work:
```ruby
def things
  yield :cat
  Fiber.yield :dog
  yield :fish
end

iter = to_enum(:things)
``` 

- `redis-rb` and `async-redis` have different interfaces for some methods and we
want to be compatible with the two libraries at least for a while. That means
that we need an adapter `lib/3scale/backend/storage_async/client.rb`. We could
simplify that and other things in our codebase by contributing to the
`async-redis` project.

- We need this line `RSpec.current_example = example` in `config.around :each`
of `spec_helper.rb` in order to make the acceptance tests pass.

- Cannot use threads in the reactor. There's one test of the suite that fails
with the async client because of this. It's in the specs for `EventStorage` and
its context is `with multiple calls at the same moment (race condition)`.

- Cannot use Redis logical databases. See [issue #135](https://github.com/3scale/apisonator/issues/135)

- We need to monkey-patch `Resque.enqueue` of the Resque lib. See the
`Backend::StorageAsync::ResqueExtensions` module for more details.
