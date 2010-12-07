TODO: This is not finished yet.

3scale traffic management API v1 to v2 migration guide
======================================================

This document describes the necessary steps to migrate to the verions 2.0 of the
3scale traffic management API.

Why migrate
-----------

- The new API's infrastructure has better performace, lower response times and higher throughtput.
- The new API offers additional features not present in the old API:
  - more flexible authentication
  - support for referrer filtering
  - more informative respones
  - better error reporting
  - live transaction feed
  - encryted connection (optionally)
- The old API will be eventually discontinued

Migration paths
---------------

The API can be use in two ways: Either using one of the 3scale privided plugins, or calling the API directly. Also, there are two modes of the API - the "Synchonous" one and the "Asynchronous" one. This makes in total four possible migration paths. This document deals with all of them.

Asynchronous mode + plugin
--------------------------

This is the simplest scenario. Step one is to download the latest plugin (see [the plugins page](http://www.3scale.net/support/plugin-download/)) and replace the old one with it. Please refer to the actual plugin documentation for more details. The differences between the interfaces of the old and new plugins are in general 


