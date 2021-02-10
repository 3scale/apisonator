# Set usages

When reporting a usage using the authrep or the report endpoints, the value
reported is added to the current one, but Apisonator offers a way to set values
instead of increasing them. If the value starts with a "#", Apisonator
interprets it as a set instead of an increase.

This feature was deprecated a long time ago. It has some tricky corners cases
documented in the test suite.

When a usage is set to 0 using `#0`, Apisonator deletes the associated stats
keys in Redis. We don't need to store stats keys set to 0. It wastes Redis
memory because for rate-limiting and stats, a key of set to 0 is equivalent to a
key that does not exist.
