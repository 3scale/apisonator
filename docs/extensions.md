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
