- Feature Name: api_extensions
- Issue: (tracking issue if applicable, leave this empty)
- RFC PR:
- Implementation PR: (leave empty, fill in when implementing)

# Summary
[summary]: #summary

Users of the backend API have become diverse and now we find that some users
could be better served with slight modifications to the API or small changes in
behaviour that don't warrant or can't wait for a new API version, yet can't just
be added as new URL parameters because of their ever growing number and
namespace pollution. This proposes a new mechanism which can be used to specify
to the 3scale backend the need to use some features that are not default because
they behave in non standard ways or because they would break the API. This
document refers to such non default features or behaviours as options or
extensions indistinctly.

# Motivation
[motivation]: #motivation

Some heavy users like XC need extra features from the authorization requests.
Some others are not interested in the responses body and would want those
requests to produce a very simple response. There is a desire to be able to
signal these in a standardized way that avoids namespace pollution, and the need
to better identify the different such options or extensions for development and
documentation purposes. This includes but is not limited to specific response
contents.

# Detailed design
[design]: #detailed-design

## Signalling extension opt-ins

The proposal talks about a method to signal the backend some non-default feature
or extension is desired.

The mechanism used for this under this document is using a single header named
`3scale-options`, with a value containing an URL-encoded list of parameters and
their values.

Separation between parameters is expected to be performed with the '&' sigil,
and separation between the parameter names and values is expected to be
performed with the '=' sigil. If any one of those characters can appear in the
parameter name or the parameter value, it should be escaped, and names and/or
values should be expected in an escaped form.

Rack's array and hash parameter types commonly used in Ruby applications are
explicitly expected to work correctly. This includes the parameter name suffixes
`[]` to indicate an array type, and `[<key>]` to indicate a hash table with key
`<key>`.

Example:

`3scale-options: no_body=1&somearray[]=one&somearray[]=2&a_hash[key]=val`

### Backwards compatibility

Currently used options (used as parameters) should be only removed after no one
else is using them (ie. some people are using `no_body` at the time of writing).

## RFC evolution

During the discussion phase of this RFC a header was chosen instead of URL
parameters, the `X-` prefix was dropped and `3scale-backend-ext` was replaced
with `3scale-options`.

Additional discussion favouring the use of the `Accept` header took place, which
the backend team dismissed as it was considered as narrowing the desired
flexibility for this feature.

The format of the header value was also subject to discussion, and a proposal
for using a CSV format was raised. The counter-argument for that pointed out
that we'd need extra dependencies and maybe be careful with corner cases, with
how we'd specify parameters for which we already have similar code (ie. URL
en(de)coding and Rack array and hash parameters).

# Drawbacks
[drawbacks]: #drawbacks

The main drawback is that this helps delay the need for an API overhaul by
extending the current (incomplete) one.

# Alternatives
[alternatives]: #alternatives

Several alternatives are possible:

- Using normal URL parameters with a prefix or a hash form.

This has a very nice advantage, which is the easy and straightforward logging.
On the other hand it consumes URL space, which is shared with the path and other
parameters and usually limited in common HTTP proxy implementations to about 8K.

Not using a prefix for parameters in this way makes them pollute the parameter
namespace and harder to find. Using a prefix however makes for extra verbosity
which counts against the used space and, depending on how it would be
implemented, using a prefix with array and hash form would be harder to parse.

Example:
`ext[no_body]=1&ext[somearray[]]=one&ext[somearray[]]=2&ext[a_hash[key]]=val`.

- Using multiple headers.

This would be similar to the proposal except a single header for each extension
would be used. This would pollute the header namespace and generally be more
verbose since the savings would usually be noticeably if each specific extension
needed quite a few parameters to offset the header name and the parameter being
repeated in the single header form.

The expectation is that most such extensions could be configured with a single
or few parameters, and in those cases the average byte count is higher. There is
also the additional restriction that some proxies won't correctly handle
specific characters in header names.

Example:
```
3scale-options-no-body: 1
3scale-options-somearray: one,2
3scale-options-a-hash: key=val
```

Regarding logging this would still need about the same provisions as the main
proposal.

- Just not doing this and keep using normal URL parameters

This would keep the list of opt-in extensions growing and polluting the URL
parameters namespace, and by the time we might want to address the problem some
users would already be heavily relying on those.

# Unresolved questions
[unresolved]: #unresolved-questions

None.