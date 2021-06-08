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

### flat_usage (integer)

This extension applies to the usage data passed into any call that accepts
usages. It instructs the software to _assume_ that the client has computed the
relations between the usage methods so that, ie. if method `m` is a parent of
method/metric `n`, then any reported hit to `n` has been added to `m`, which in
turn should also be present in the usage specified by the client. Note that
failing to compute this properly will result in data that does not make sense,
such as having a limited parent with a child that goes over the parent
limits.

#### Accepted values

- 0: disable the extension (default)
- 1: enable the extension, blindly trust the specified usage values (unsafe)

Values over 1 are currently undefined, but in the future could provide some
checking to ensure data is consistent, ie. usage data with `n` incremented in
5 necessarily means `n` parent, if existing, should be specified with a minimum
of 5, not counting any other potential children.

### list_app_keys (integer)

This extension just outputs an XML `app_keys` section in authorization responses
so that application keys registered to it will be listed there with the following
format:

> \<app_keys app="app_id" svc="service_id"\>
>   \<key id="app_key1"/\>
>    ...
>   \<key id="app_keyN"/\>
> \</app_keys>

Applications that don't have associated keys will just show an empty `app_keys`
section. Also do note that at the time of writing there is a maximum of 256
such keys listed, and there is no guarantee that two successive calls will end
up returning the same 256 keys for larger sets, nor the same order in any case.

#### Accepted values

- 0: disable the extension (default)
- 1: enable the extension, always output the app_keys section regardless of
     whether an application actually has any associated keys.

Values over 1 are currently undefined, but in the future they might become
significant. For example they could provide the maximum number of desired
application keys returned.

### no_body (boolean)

This instructs the software to avoid generating response bodies for certain endpoints.
In particular, this is useful to avoid generating a large response in the authorization
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

* `3scale-limit-remaining`: An integer stating the number of hits left for the
  _full combination_ of metrics authorized in this call before the rate limiting
  logic would start denying authorizations _for the current period_. A negative
  integer value means there is no limit in the number of hits.
* `3scale-limit-reset`: An integer stating the number of seconds left for the
  current limiting period to elapse. A negative integer value means there is no
  limit in time.
* `3scale-limit-max-value`: An integer stating the maximum total number of hits
  allowed in the current limiting period.

When a `usage` is specified, only the metrics specified in that usage and their
parent metrics are taken into account when calculating the limit headers.

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

Relying on the number of hits declared in the header for caching purposes should
be done carefully to take into account potential concurrent requests reporting
hits to any one of the metrics in the authorization call. Additionally, there is
also the possibility that limits that apply could be updated in the meantime.
Out of band mechanisms for detecting that limits have been changed and caching
must be invalidated are out of scope for this extension.

#### Limit Reset

The time in the limit reset header specifies the number of seconds after which
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
performance (ie. response time) is to be expected, especially when a large number
of limits apply.

#### Accepted values

- 0: disable the extension (default)
- 1: enable the extension
