# Openshift Horizontal Pod Autoscaling (HPA)

It is possible to configure Apisonator to automatically scale when deployed in
Openshift. This document details the required setup.
Note that this guide focuses on Openshift, but with minimal changes, it's
possible to have the same setup on Kubernetes. You can learn about Kubernetes
HPA
[here](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/).

## Pre-requisites

- Have a working installation of 3scale in an Openshift cluster. You can use [this
guide](https://github.com/3scale/3scale-operator/blob/master/doc/template-user-guide.md).

## Openshift HPA

Openshift Horizontal Pod Autoscaling (HPA) allows to scale pods horizontally by
specifying the minimum and maximum number of pods that should be deployed and
the target CPU utilization. For more details check the [official Openshift
docs](https://docs.openshift.com/container-platform/4.1/nodes/pods/nodes-pods-autoscaling.html).

## Async

Apisonator can be configured to use a non-blocking Redis client. With this
feature enabled, a single process should use a whole CPU core when properly
tuned. This means that we can enable Openshift HPA using the CPU utilization as
the scaling metric.

To learn more about how the async Redis client works, check this [design
doc](./async.md).

## Setup

### Redis databases

The standard 3scale deployment uses a single Redis pod and sets both the resque
DB and the data DB in the same Redis process under different DB indexes. If an
external Redis is used the URLs set in `CONFIG_REDIS_PROXY` and 
`CONFIG_QUEUES_MASTER_NAME` can be configured to either two separate Redis instances
(e.g. `redis://backend-queues.example.com:6379` and `redis://backend-storage.example.com:6379`),
or a single Redis instance with separate databases (e.g. `redis://backend.example.com:6379/0`
and `redis://backend.example.com:6379/1`).

### Enable async

- Set the `CONFIG_REDIS_ASYNC` to true in the listener and worker deployment configs.
- Configure listeners to use the Falcon web-server instead of Puma. In order to
do this, modify the command in the listener deployment config. Replace this:
```yaml
spec:
  containers:
    - args:
        - bin/3scale_backend
        - start
        - '-e'
        - production
        - '-p'
        - '3000'
        - '-x'
        - /dev/stdout
```

with:
```yaml
spec:
  containers:
    - args:
        - bin/3scale_backend
        - '-s'
        - falcon
        - start
        - '-e'
        - production
        - '-p'
        - '3000'
        - '-x'
        - /dev/stdout
```
- Set the `LISTENER_WORKERS` env to 1 in the listener deployment. This will
deploy 1 Falcon worker per pod.

### Set up horizontal pod autoscaling

We need to decide the target CPU usage. It is defined as a percentage of the
requested CPU cores. In an ideal case, we know that both the listener and the
worker should use 1 CPU core when using the async redis lib. However, we need to
leave some margin for possible inefficiencies, so we can target 0.8 CPU cores,
for example. Thus, if we define, for example, a request of 1 CPU for each pod,
we could set the target CPU usage to 80%.

We also need to define the minimum and the maximum number of pods. The example
below uses 1 and 10, but adapt those values according to the resources available
in your Openshift cluster.

Configure HPA both in listeners and workers:
```bash
oc autoscale dc/backend-listener --min 1 --max 10 --cpu-percent=80
oc autoscale dc/backend-worker --min 1 --max 10 --cpu-percent=80
```

To check the decisions made by the auto-scaler as well as information about the
current number of pods vs the desired number:
```bash
oc describe hpa backend-listener
oc describe hpa backend-worker
```
