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
DB and the data DB in the same Redis process under different DB indexes. This is
not supported by the async redis library, so we need to either place both DBs in
the same Redis process or use two separate ones. To configure this, change the
`CONFIG_REDIS_PROXY` and `REDIS_QUEUES_URL` envs in the listener and worker
deployment configs.

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
requested CPU cores. In a default installation, the backend-listener pod
requests 0.5 CPU cores. In an ideal case, we know that both the listener and the
worker should use 1 CPU core when using the async redis lib. However, we need to
leave some margin for possible inefficiencies, so we can target 0.8 CPU cores,
for example. 0.8/0.5 = 1.6, so we need to define a CPU % of 160 for the
listener. In a default installation, the backend-worker pod requests 0.150 CPU
cores. Following the same logic, we need to define a target CPU of 533
(0.8/0.150 = 5.33). Pay attention to the CPU request of each pod, as they might
change between versions, and adapt the target CPU % values accordingly.

We also need to define the minimum and the maximum number of pods. The example
below uses 1 and 10, but adapt those values according to the resources available
in your Openshift cluster.

Configure HPA both in listeners and workers:
```bash
oc autoscale dc/backend-listener --min 1 --max 10 --cpu-percent=160
oc autoscale dc/backend-worker --min 1 --max 10 --cpu-percent=533
```

To check the decisions made by the auto-scaler as well as information about the
current number of pods vs the desired number:
```bash
oc describe hpa backend-listener
oc describe hpa backend-worker
```
