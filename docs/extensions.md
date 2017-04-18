# Extensions

## Purpose

Extensions are features or behaviours that are not part of the standard API for a variety
of reasons. Examples of such reasons are:

- The feature is experimental, not mature enough, or undocumented.
- The feature is only usable in very specific conditions.
- The feature would break existing users or is otherwise incompatible with the API.
- The API is frozen or hard to extend with support for this feature.

Such extensions can be used as specified in the API Extensions RFC.

## List of supported extensions

### no_body (boolean)

This instructs the software to avoid generating response bodies for certain endpoints.
In particular, this is useful to avoid generating large response in the authorization
endpoints, but can also apply to other endpoints as long as it makes sense to avoid
generating the response's body.

#### Accepted values

- 0: disable the extension (default)
- 1: enable the extension

### rejection_reason_header (boolean)

This is used by authorization endpoints to provide a header named "3scale-rejection-reason"
that provides an error code describing the different reasons an authorization can be
denied. The reason codes correspond to the error codes that authorization calls generate
within the response body. Only one such code is returned when those calls result in an
authorization denied status.

This is particularly useful to combine with the `no_body` extension.

#### Accepted values

- 0: disable the extension (default)
- 1: enable the extension

### limit_headers (boolean)

When enabled this extension requests that the headers below be returned when
calling endpoints that perform authorizations _and such endpoints can be
processed correctly_ (ie. no other errors such as authentication or
non-existing metrics occur):

* `3scale-limit-remaining`: An integer stating the amount of hits left for the
  _full combination_ of metrics authorized in this call before the rate limiting
  logic would start denying authorizations _for the current period_. A negative
  integer value means there is no limit in the amount of hits.
* `3scale-limit-reset`: An integer stating the amount of seconds left for the
  current limiting period to elapse. A negative integer value means there is no
  limit in time.

The remaining hits header states how many _identical calls_ will be authorized by
3scale's rate limiting logic. Be warned that this means exactly that, not that
other orthogonal logic will end up causing an authorization request to be
denied.

The data returned in the headers is data that _can be inferred_ from the
authorization call body, and is defined as the longest period with the most
constrained amount of hits left applying to the combination of metrics being
authorized, with the latter constraint taking precedence. For example, 1
remaining hit for a period of an hour takes precedence over 10 remaining hits
for a period of a day, and it still takes precedence over 1 remaining hit for
a period of a minute.

#### Caching remaining hits

Relying on the amount of hits declared in the header for caching purposes should
be done carefully to take into account potential concurrent requests reporting
hits to any one of the metrics in the authorization call. Additionally there is
also the possibility that limits that apply could be updated in the meantime.
Out of band mechanisms for detecting that limits have been changed and caching
must be invalidated are out of scope for this extension.

#### Limit Reset

The time in the limit reset header specifies the amount of seconds after which
the limiting period is guaranteed to expire (unless it is a negative value) and
a new limit will be considered. That does not take into account networking or
processing delays, and it is a rounded up value representing the clock
difference between _a specific backend node_ and the end of the period. While this
should effectively be a safe upper bound, there is no universally synchronized
backend clock, and different nodes might differ in their concept of the current
time, as well as have clocks with different drifts. It is expected for those
differences to be minor, but you should still consider them when dealing with
this information.

#### Nominal amount of hits

Additional headers _may_ be added in the future to state the nominal amount of
hits for the most constrained limit that will start after the current period
ends, either through this extension or another one. Such headers have been
discarded as of writing because they are expensive to compute and have limited
usefulness. New authorization calls after the remaining time specified has
elapsed can be used to obtain nominal values.

#### Performance

Note that this extension forces backend to compute the headers and thus lower
performance (ie. response time) is to be expected, specially when a large amount
of limits apply.

#### Accepted values

- 0: disable the extension (default)
- 1: enable the extension
