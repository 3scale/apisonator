- Feature Name: error_responses
- Issue:
- RFC PR:
- Implementation PR: (leave empty, fill in when implemented)

# Summary
[summary]: #summary

This RFC details which HTTP status codes are used in Backend for errors in
publicly facing endpoints and which scenarios return every one of them, along
with the contents that each response should include. This is explitcitly opting
out of definitions for internal endpoints.

# Motivation
[motivation]: #motivation

Currently the HTTP status codes for error responses used in Backend and
specified in the documentation are inconsistent and not in line with some common
expectations. We want to fix this by agreeing on the status codes returned
depending on the reported problem as well as the format of the response. Much in
the same vein, we want to make sure we state what is the format we expect in the
response's body.

# Detailed design
[design]: #detailed-design

## Response status codes

Unfortunately, there is significant overlap and confusion between HTTP status
codes used for signalling protocol conditions versus application-specific
semantics. Even the protocol's RFC has mixed codes in this regard.

We will favor HTTP-specific semantics when they make the most sense for users of
the protocol itself. For example, we would not want to use code `502 Bad Gateway`
in Backend because that only makes sense for HTTP gateways and can confuse our
infrastructure software as well as our monitoring.

Infrastructure responses:

* `400 Bad Request`:
  - An invalid request was sent. This typically means it was ill-formed, contained
  a very long URI or body, specified a broken Content-Length, its syntax
  could not be understood, or otherwise does not adhere to the HTTP spec.
* `403 Forbidden`:
  - The request requires HTTP authorization. The response contains which kind of
  authorization is needed.
* `429 Too Many Requests`:
  - The provider reached the maximum rate of requests. Throttling is needed.
* `502 Bad Gateway`:
  - An intermediate proxy got an invalid response from another proxy or the
  application server.
* `503 Service Unavailable`:
  - An intermediate proxy could not find a suitable proxy or application server to
  send the request to. This typically means the upstream servers are too busy or
  unavailable.
* `504 Gateway Timeout`:
  - An intermediate proxy could not get a response in time from an upstream proxy
  or application server.

Backend responses:

* `400 Bad Request`:
  - An invalid request was sent. This typically means its syntax could not be
  understood or the parameters are too long. This code is also used as catch-all
  for all requests that resulted in client errors without a better match.
* `403 Forbidden`:
  - The request tried to access a resource that it did not have access to or which
  was not active at that moment.
* `404 Not Found`:
  - The request tried to access a non-existing resource. This can be, for example,
  a no longer existing application or metric, but is also used in case the
  provider's key could not be found, but it is also used in case the endpoint
  requested does not exist.
* `409 Conflict`:
  - The request's reported usage goes over the limits set for that specific
  application or user or some other condition for this application (not enabled
  or invalid/missing key) or service (not enabled or not OAuth-enabled).
* `422 Unprocessable entity`:
  - One or more required parameters are missing or have invalid data.
* `500 Internal Server Error`:
  - The application server found an application programming error while processing
  this request.

## Response contents

Response contents are defined here as those error responses that are originated
in the Backend application **only**. *Responses produced in other layers, such as
proxies or other infrastructure, might be limited to just an HTTP status code
and do not necessarily follow these rules.*

The response should use an appropriate HTTP content type. This is currently a
vendor-specific XML for Backend, but could be JSON or any other widely used
format. This should be explicited as an HTTP header, and should adhere to the
respective specifications and schemas where possible and convenient.

The response body should contain the fields below:

* `error_code`: a single word intended for machine processing describing the
                error ocurred in a generic manner. Must be unique.
* `message`: a human-readable description of the error.

We have historically used the class name downcased and using underscores as the
contents for the `error_code` field. The only requirement is that it is unique.

The field *message* should try to be as specific as possible as long as it is
convenient both from the computational and the security points of view. For
example, you would not want to disclose some sensitive details like secrets or
specify the whole list of not found entities if just finding one is enough for
an error response.

Note that authorization failures returning a 409 HTTP status code don't currently
use this scheme due to backwards compatibility reasons and the fact that in most
cases failed authorizations when integration is correctly done are not errors but
just a "No" response to the question "Is this usage authorized?". See the
`authorization_failed` error below for details.

## Currently known `error_code`s and proposed classification

This is a list of known errors that we want to handle and under which codes we
classify them. It does not aim to be comprehensive, but instead to be used as a
guide for new errors to be classified and server documentation purposes.

The main idea is that we group errors semantically. For example, although
technically not finding a provider key in the database would be a `404 Not Found`,
we can consider that request as forbidden.

Note: some current errors could be rethought as they serve different semantics,
ie. parameter X is missing or not matching criteria Y.

* `error`:
  [400] Generic client error. Not to be used if a more specific code exists.
    - `not_valid_data`:
      Found data not being valid UTF-8.
    - `bad_request`:
      The request contains syntax errors.
    - `content_type_invalid`:
      A request was performed with an invalid Content-Type header. This usually
      happens when POST'ing with a header with anything other than either
      `application/x-www-form-urlencoded` or `multipart/form-data`. We default
      to the former correct Content-Type if no header is present, so it is ok to
      not send one as long as the body is properly encoded.
* `forbidden`:
  [403] A resource can not be used because of authorization or being disabled.
    - `provider_key_invalid`:
      The specified provider key is unauthorized.
    - `user_requires_registration`:
      The specified user is missing or is not registered with the service.
    - `user_key_invalid`:
      The specified user key is invalid.
    - `authentication_error`:
      The application requires a user_key but it is missing.
    - `provider_key_or_service_token_required`:
      A provider key or a service token are required, but neither were given.
    - `service_token_invalid`:
      The specified service token is unauthorized.
* `not_found`:
  [404] A resource could not be found. This is never included if the error
  refers to a non-existing endpoint (such as Sinatra not matching a route).
    - `application_not_found`:
      Application id was not found.
    - `service_id_invalid`:
      The specified service id was not found.
    - `metric_invalid`:
      The specified metric was not found.
* `authorization_failed`:
  [409] Authorization denied because of rate limiting or wrong credentials.
  *Note*: the description of the below codes is always placed in the reason
  tag of the XML response, and the code itself is not specified under the
  error_code tag, but available as the value of a header if the rejection reason
  extension is enabled.
    - `limits_exceeded`:
      The limit for a current period on a reported metric has been exceeded.
    - `oauth_not_enabled`:
      The service does not have OAuth enabled.
    - `redirect_uri_invalid`:
      The redirect URI does not match the one configured.
    - `redirect_url_invalid`:
      See `redirect_uri_invalid`.
    - `application_not_active`:
      The specified application is not active.
    - `application_key_invalid`:
      Application key is missing or invalid
    - `referrer_not_allowed`:
      The referrer specified does not match allowed referrers.
* `invalid`:
  [422] One or more parameters contain invalid data or format.
    - `application_has_inconsistent_data`:
      Application has inconsistent data and can't be saved.
    - `referrer_filter_invalid`:
      The referrer filter is missing or blank.
    - `required_params_missing`:
      One or more required parameters are missing.
    - `usage_value_invalid`:
      One or more usage values for a given metric are missing or invalid.
    - `service_id_missing`:
      The service ID is missing or blank.

# Drawbacks
[drawbacks]: #drawbacks

The two main problems with going forward with this are:

* Breaking API status codes. This is the price we get for fixing this.
* A review process to make sure nothing escapes these rules as well as changes
  in code to adapt to them.

# Alternatives
[alternatives]: #alternatives

We can skip this and live confused as to what codes does Backend return in
different circumstances.

# Unresolved questions
[unresolved]: #unresolved-questions

The usage of the different status codes is arbitrary. We could have gone for
a different set of status codes as well as using them for different things.
Semantics matter, but this document wants first and foremost to serve as
documentation rather than being a perfect way to classify error codes.
