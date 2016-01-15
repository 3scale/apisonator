- Feature Name: limit-past-and-future-reports
- Issue:
- RFC PR:
- Implementation PR:

# Summary
[summary]: #summary

Currently, we allow clients to report transactions in the future and in the
past without any kind of limit. This means that clients can report transactions
from 2000 and from 2050, for example. We need to limit this.

We need to allow clients to report past transactions so they can batch their
transactions. We can also allow them to report in the future to be protected
against weird errors that might happen with server clock synchronization and
things like that. However, we need to decide on reasonable time frames for
those two situations.

What we propose is:

1. Limit past transactions to 24h in the past.
2. Limit future transactions to 1h in the future.
3. When a client reports a transaction with a timestamp that falls outside the
   limits established, he will receive an integration error.

# Motivation
[motivation]: #motivation

We need to do this for the new analytics system. Analytics systems rely on
'closed periods' to function well. These systems typically run once a day or a
few times a day. If data from years ago can be modified, we are forcing the
system to recalculate everything each time it runs. With high volumes of data
this is not reasonable.

# Detailed design
[design]: #detailed-design

`ThreeScale::Backend::Transaction#ensure_on_time!` should be responsible for
checking that the timestamp of the transaction falls within the established
limits. Also, an integration error should be created when this happens.

# Drawbacks
[drawbacks]: #drawbacks

Clients reporting transactions too far in the past or in the future will be
affected.
