# Apisonator

[![Docker Repository on Quay](https://quay.io/repository/3scale/apisonator/status "Docker Repository on Quay")](https://quay.io/repository/3scale/apisonator)
[![CircleCI](https://circleci.com/gh/3scale/apisonator.svg?style=shield)](https://circleci.com/gh/3scale/apisonator)
[![Maintainability](https://api.codeclimate.com/v1/badges/d2cea8016f0089cb2fd6/maintainability)](https://codeclimate.com/github/3scale/apisonator/maintainability)

This software is licensed under the [Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0).

See the LICENSE and NOTICE files that should have been provided along with this
software for details.

## Description

This is the Red Hat 3scale API Management backend.

It has the following components:

### Apisonator listener

It provides the point of entry of the API Management Platform's Backend.
The Service management API (SM API) is provided to authorize and report consumer
API requests.

Three main operations can be performed with this API:

 * Report: Reports a number of hits to one or more metrics, performing the
   corresponding metric aggregations
 * Authorize: Authorize a request. The authorization of a request checks that:
   * The provided API key to authorize the request is valid
   * The current usage metrics of the API related to the request are within
     the specified limits
 * Authrep: Combination of both the above

Make sure to read the corresponding Swagger-generated documentation of this
operations, located in [docs/active_docs/Service Management API.json](docs%2Factive_docs%2FService%20Management%20API.json)

It attempts to respond with lowest possible latency, performing minimal work
and offloading other work to Apisonator workers by enqueuing tasks into job queues.

This component needs access to a Redis database to perform the following actions:
 * Enqueue reports, which will be processed by the Apisonator worker component
 * Perform authorization of the requests

These two actions can be configured to be performed in different Redis
databases if desired (see the [Prerequisites](#prerequisites)
and [Configuration](#configuration) sections).

Finally, another API named 'Internal API' is provided to configure services
in Apisonator. This API is intended only for administrative purposes and not
for general consumption. Therefore, usage of this API should be protected or
not exposed to untrusted parties. You can also generate its documentation with
Rake tasks. The [Pisoni](https://github.com/3scale/pisoni) API client can be
used to interact with the Internal API.

To quickly test Apisonator, random services can be created and configured on it
via the use of the 'Buddhi' tool located in our performance tests
toolkit: [3scale perftest-toolkit](https://github.com/3scale/perftest-toolkit/).

This component may also be referred to as '3scale_backend'.

### Apisonator worker

It is responsible for performing background tasks off-loaded from
Apisonator listeners (enqueued jobs).

The worker component takes care of running these enqueued jobs, mainly related
to reporting of previous traffic.

Specifically, this component:
 * Dequeues and runs the report jobs that have been submitted to the Redis
   background jobs database by the Apisonator listener/s or the
   Apisonator failed jobs rescheduler
 * Stores the results of running the report jobs in the Redis Storage database

This component may also be referred to as '3scale_backend_worker'.

### Apisonator failed jobs rescheduler

This is a simple task that acts as a cron scheduler to requeue jobs that failed
when being processed by an Apisonator worker. The jobs are requeued into
the Redis background jobs database.

This component may also be referred to as 'backend-cron'.

## Development

See the file [DEVELOPMENT](DEVELOPMENT.md)

## Documentation

You can find documentation about Apisonator (also called referred to as `3scale
backend`) at the [Red Hat 3scale API Management product pages](https://access.redhat.com/products/red-hat-3scale/).

Documentation about specific parts of Apisonator (APIs, specs, behaviour, etc)
can be found in the [`docs`](https://github.com/3scale/apisonator/tree/master/docs) folder, though this is mostly meant for development and design purposes rather
than user documentation.

## How to run

### Prerequisites

* Docker (requires version 1.10.0 or later)
* A Redis database, used to store API request statistics and services. Also
  used to perform API requests authorizations. In Apisonator this database
  is commonly referred to as 'Redis Storage'
* A Redis database, used to store background jobs. The Redis Resque library
  is used for this. In Apisonator this database is commonly referred to as
  'Redis Resque', or as the 'background jobs database'

The two previous Redis databases can be configured in the following ways:

 * In a single machine/vm, using a single Redis process by specifying
   different database identifiers, which is supported by the Redis URI
	 specification. i.e. redis://host:port/0, redis://host:port/1
 * In a single machine/vm, using different Redis processes with different
   assigned ports
 * In separate machines/vms

The first thing you will need is cloning the project:
> `$ git clone git@github.com:3scale/apisonator.git`

Next cd into the directory, `cd apisonator`.

### Apisonator image generation

Go to the `openshift` directory and execute `make build`. This will generate
a local docker image named `amp:apisonator-<version_number>` based on CentOS Stream 8.

### Configuration

To run any Apisonator component, application-related environment variables must
be previously set. This can be done by setting them via the `--env` flag in
Docker or by placing them in a ENV file and setting the ENV file in Docker via
the `--env-file` flag.

The most important variables to set are:

 * CONFIG_QUEUES_MASTER_NAME: Set this to the [`redis://` URL](http://www.iana.org/assignments/uri-schemes/prov/redis)
   of where the Redis Resque has been installed
 * CONFIG_REDIS_PROXY: Set this to the [`redis://` URL](http://www.iana.org/assignments/uri-schemes/prov/redis)
   of where the Redis Storage has been installed
 * CONFIG_INTERNAL_API_USER: Set this to an arbitrary username <username>
   that will be the one used to be able to use the Apisonator internal API
 * CONFIG_INTERNAL_API_PASSWORD: Set this to an arbitrary
   password <password> that will be the one used to be able to use the
   Apisonator internal API
 * RACK_ENV: Set this to 'production'

A complete list of configuration variables that can be set can be
found in the file `openshift/3scale_backend.conf`

An example of an ENV file can be found at `openshift/.env.test`

### Automatic execution (with Makefile)

Makefile rules can be run to execute the different Apisonator components
with some predefined behaviour. To do this a file named `.env` in
the `openshift` directory must be created before.

Once this has been performed, go to the `openshift` directory and execute
one of the available Makefile commands to run Apisonator components:

#### Apisonator Listener

Execute the Apisonator Listener, exposing the port 3001:

```
make listener
```

#### Apisonator Worker

```
make worker
```

#### Apisonator failed jobs rescheduler

Execute the 'cron' Apisonator component:

```
make cron
```

#### Apisonator bash shell

Execute a bash shell with the Apisonator source code with all the available
components:

```
make bash
```

### Manual execution

Another way of executing the Apisonator components is by running a container
using the previously generated Apisonator image:

#### Apisonator Listener

To run an Apisonator listener, the script bin/3scale_backend is used. To
run it from a previously generated Apisonator docker image:

```
docker run -p 3001:3001 --env-file <myenv_file> -it amp:apisonator-<version_number> 3scale_backend start -p 3001 -x /dev/stdout
```

You can see all the available options of the apisonator listener by executing:

```
docker run -it amp:apisonator-<version_number> 3scale_backend help
```

#### Apisonator Worker

```
docker run --env-file <myenv_file> -it amp:apisonator-<version_number> 3scale_backend_worker
```

#### Apisonator failed jobs rescheduler

```
docker run --env-file <myenv_file> -it amp:apisonator-<version_number> backend-cron
```

#### Apisonator bash shell

```
docker run --env-file <myenv_file> -it amp:apisonator-<version_number> bash
```
