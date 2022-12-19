# Features

This document lists and briefly explains the functionality offered by
Apisonator.

- [Authorization of applications](#authorization-of-applications)
- [Rate-limit of applications](#rate-limit-of-applications)
- [Aggregation of usage stats](#aggregation-of-usage-stats)
- [Aggregation of response codes](#aggregation-of-response-codes)
- [Quotas](#quotas)
- [Alerts](#alerts)
- [Events](#events)
- [Integration errors](#integration-errors)
- [Usage metrics of the Porta master account](#usage-metrics-of-the-porta-master-account)
- [Export data to Analytics system](#export-data-to-analytics-system)
- [Internal management API](#internal-management-api)

## Authorization of applications

Requests are authorized based on some credentials that identify a service
(provider key, service token) and some credentials that identify an application
(app ID + app key, user key, OAuth token).

## Rate-limit of applications

Rate limits are applied for combinations of {service, application, metric}. The
limits can be per minute, hour, day, week, month, year, and "eternity". They are
applied in calendar periods of time. So for example, if the limit is per year
and the year is 2020, when applying the limit, Apisonator will only take into
account the counters starting from Jan 1st 2020, not from a year ago.

## Aggregation of usage stats

Apisonator aggregates usage stats by the same periods used for rate-limiting,
except for minute. It aggregates data by {service, metric} and also {service,
application, metric}. This allows an external system to query the usage for a given
month, year, etc. efficiently.

## Aggregation of response codes

Apisonator also aggregates response codes using the same periods used to
aggregate usage stats. These response codes are the ones returned by the
upstream API and are sent to Apisonator via APIcast or other integration mechanisms (Istio adapter, Java plugin, etc.).

## Quotas

Apisonator optionally returns the remaining amount of hits left before the rate
limiting logic would start denying authorizations.

## Alerts

Apisonator sends usage alerts to Porta via a webhook. These alerts can be
configured to be triggered when an application reaches some % of its usage quota
for any given metric. This feature supports a fixed set of thresholds: 50%, 80%,
90%, 100%, 120%, 150%, 200%, and 300%. Notice that defining alerts based on
response codes is not supported.

## Events

Apisonator sends some events to Porta via a webhook. These events trigger when
an application has traffic for the first time, and also, when it has traffic for
the first time in the current day.

## Integration errors

When Apisonator receives invalid application keys, invalid metrics, or there is
any other kind of error that suggests that the user did not configure the
integration of his API with 3scale correctly, Apisonator stores these errors so
they can be retrieved efficiently by Porta in the view that shows "integration
errors".

## Usage metrics of the Porta master account

Apisonator keeps track of the authorize and reports call done for each service
under the master account.
In Porta, this is used to know the usage that each provider makes of the
platform and apply pricing plans based on this usage.

## Internal management API

There's an API that exposes CRUD endpoints for many of the domain entities
(applications, services, usage limits, etc.). We call this API "Internal API"
and it is the one that Porta uses to keep the data between both systems
synchronized. This API also exposes some of the information mentioned above,
like the real-time traffic and the integration errors.
