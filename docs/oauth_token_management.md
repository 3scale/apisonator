# OAuth Token Management Endpoints

## Purpose

This is the specification for the endpoints that allow you to create, list and delete
OAuth tokens. Those are later used in the calls that accept OAuth access tokens.

## Error responses (4XX status)

All endpoints provide the same XML body structure when erroring:
* XML Node: `<error>` consisting of the attribute and value below.
  * XML Attribute: `code` with a machine-readable value identifying the type of error.
  * Value: Human-readable string describing the error.

## Storing a new token

### Description

Store a token associated with a service and application in the 3scale backend in
order to perform checks against it with authorization calls.

### Endpoint
**POST** `/services/<service_id>/oauth_access_tokens.xml`

### Parameters
  * `provider_key`: Optional (but required unless `service_token` is specified).
    Used for authentication purposes.
  * `service_token`: Optional (but required unless `provider_key` is specified).
    Used for authentication purposes.
  * `service_id`: Required. Specified in path. The stored token will be associated
    to this service.
  * `app_id`: Required. The stored token will be associated to this application *in
    addition* to the specified service.
  * `token`: Required. The token to store.
  * `ttl`: Optional. Specifies the amount of time in seconds since the current time
    during which the token will be considered valid. If unspecified the token will
    not expire (which is *not recommended*).

### Response
  * Status:
    * `200`: The token was stored successfully.
    * `403`: Authentication error. The combination of `provider_key` or `service_token`
             with the specified `service_id` is invalid.
    * `403`: Access token already exists. You must delete it or let it expire.
    * `403`: Token storage error.
    * `404`: The specified `app_id` does not exist.
    * `422`: The specified `ttl` is invalid or not an integer greater than zero.
    * `422`: The specified `token` is too big or has an invalid format.

## Deleting a token

### Description
Delete a token previously stored in the 3scale backend.

### Endpoint
**DELETE** `/services/<service_id>/oauth_access_tokens/<token>.xml`

### Parameters
  * `provider_key`: Optional (but required unless `service_token` is specified).
    Used for authentication purposes.
  * `service_token`: Optional (but required unless `provider_key` is specified).
    Used for authentication purposes.
  * `service_id`: Required. Specified in path. The service associated to this token.
  * `token`: Required. Specified in path. The token that will be deleted.

### Response
  * Status:
    * `200`: The token was deleted successfully.
    * `403`: Authentication error. The combination of `provider_key` or `service_token`
             with the specified `service_id` is invalid.
    * `404`: The specified token does not exist.

## Reading a token

### Description
Read the details associated to a previously stored token.

### Endpoint
**GET** `/services/<service_id>/oauth_access_tokens/<token>.xml`

### Parameters
  * `provider_key`: Optional (but required unless `service_token` is specified).
    Used for authentication purposes.
  * `service_token`: Optional (but required unless `provider_key` is specified).
    Used for authentication purposes.
  * `service_id`: Required. Specified in path. The service associated to this token.
  * `token`: Required. Specified in path. The token to be retrieved.

### Response
  * Status:
    * `200`: The token details were retrieved successfully.
    * `403`: Authentication error. The combination of `provider_key` or `service_token`
             with the specified `service_id` is invalid.
    * `404`: The specified token does not exist.
  * Body:
    * XML Node: `<application>` containing a single node below.
      * XML Node: `<app_id>` containing a single value below.
        * Value: application identifier

## List tokens

### Description
List tokens stored in the 3scale backend associated to a given service and application.

### Endpoint
**GET** `/services/<service_id>/applications/<app_id>/oauth_access_tokens.xml`

### Parameters
  * `provider_key`: Optional (but required unless `service_token` is specified).
    Used for authentication purposes.
  * `service_token`: Optional (but required unless `provider_key` is specified).
    Used for authentication purposes.
  * `service_id`: Required. Specified in path. The service for which the specified
    application belongs to.
  * `app_id`: Required. Specified in path. The application for which to retrieve the
              list of associated tokens. This is in addition to the specified service.

### Response
  * Status:
    * `200`: The token was deleted successfully.
    * `403`: Authentication error. The combination of `provider_key` or `service_token`
             with the specified `service_id` is invalid.
    * `404`: The specified application does not exist.
  * Body:
    * XML Node: `<oauth_access_tokens>` consisting of 0 or more nodes below.
      * XML Node: `<oauth_access_token>` consisting of the attributes and values below.
        * Attribute: `ttl` with value -1 if permanent token, positive integer seconds
                     otherwise.
        * Value: OAuth token.
