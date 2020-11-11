# Limits

There is a surprisingly common test people like to perform when they first encounter
Apisonator's limits. This test consists of setting up a service, an application, and
a limit to an arbitrary metric, and trying it out.

For example, setting up a 5/minute limit on the "Hits" metric.

When they do this, they usually fire up curl or a similar tool to try our whether this
limit is being enforced. To their surprise, some times they can actually go over the
configured limit. And then big question marks show up in their thoughts.

And contrary to what people might initially believe, no, that is not a bug, it in fact
is a feature!

Well, turns out that Apisonator is taking a trade-off for you: it is trading accuracy
for lower latency when it authorizes and reports (authrep operation) your requests!

## How so?

When you start exposing your APIs to the real world, it is often the case that you do
not need a lot of accuracy on how many exact hits some endpoint received. You might be
just fine with something like "1000 hits/minute", or "1000000 hits/hour". Having some
small percentage of those hits accepted to, say, reach 1010 hits/minute, or 1000050
hits/hour is usually not a big deal. What instead _is_ a big deal is latencies for a
yes/no result to request authorization. The time Apisonator takes to authorize or deny
a request is directly affecting your API latency, so we prefer to take a very quick
look at the current counters and respond as fast as possible rather than waiting for
all pending operations on a counter to complete.

In other words, you might have at any given time a (usually surprisingly small) set of
requests in-flight for any given endpoint. That is the maximum amount of hits your
API is likely to go over limits with the architecture Apisonator uses. The reason is
that whenever we receive an authrep request, we immediately take a look at the current
counters for whatever metrics are affected, compute whether the request would go over
the limits, and if so we deny the request, and if it is approved, we enqueue a job for
our background workers to process in which the right counters are incremented. This
means that previous and parallel requests for any given set of metrics for which their
corresponding background jobs have not yet been enqueued or processed are not being
taken into account.

That is, if you serialize calls to authrep on a metric, you are likely to get the
expected results. But if you instead perform calls in parallel, you are much more
likely to get seemingly non sensical results and going over the limits.

In particular you could get authrep requests stating that the current counter is the
same for 2 or more requests. You could also get your requests denied because the
current counter is, say, 8 out of a limit of 5. The reason: in-flight jobs are being
processed by a background worker while your query is being responded and their results
not yet committed by the time Apisonator responds to you.

## Hands on

This can be explored with the `limits.sh` script in the `contrib/scripts`. You can
use environment variable to configure it (and/or hardcode defaults in it) and invoke
multiple tests capturing the output to files. In general, you will see that whenever
a few requests are performed in parallel, you'll see the above behavior. On the other
hand, when you invoke the requests serially, you'll see the expected behavior.

Also, note that one of the issues people get caught by surprise in is issuing requests
in different limiting periods. The time Apisonator has is the time it will use to
classify counters, so pay attention to the responses containing the start and end of
the period. If you use minutes to test this you could be unlucky and start your test
right before the current minute period ends (note periods are absolute in Apisonator,
according to its own idea of time, ie. the clock source where it is running), and by
the time you finish your test your last calls were assigned to the next minute. So
you need to check the response bodies this script outputs.

Example test for a limit of 5 requests/minute on "Hits" on an instance of Apisonator
running on a container:

> $ FILE=test PARALLEL=y NUM_REQUESTS=8 HOST="backend-listener" METRIC="Hits" SVC_TOKEN="abc" SVC_ID="123" USER_KEY="deadbeef" ./limits.sh

You can omit the `PARALLEL=y` setting to perform requests serially, or you could
introduce small pauses in between parallel requests with ie. `SLEEP=0.01`.

In general, if you want accuracy to be greater you will have to increase the number
of workers processing background jobs (ie. backend-worker). Those workers have
historically worked in one job at a time, so if you have up to N parallel requests
in-flight, you want at least N such workers. (Note: async mode when enabled will
actually allow a single worker to take more than a single job).
