# Benchmarking the performance

Apisonator is designed to process a lot of requests quickly and sometimes minor changes or changes in the underlying libraries results in significant performance degradation.

Due to differences in the underlying hardware, a fixed numbers can't be given. Always compare performance with and without your changes.

Another thing to keep in mind is that a local redis has a significantly lower latency than a remote one. So a real world setup benchmark will be much more valuable. For example locally the `sync` mode will be very much comparable to `async`. But in reality `sync` is much slower at present.

## Check worker performance locally

Run the following rake task with `CONFIG_REDIS_ASYNC=false` or `CONFIG_REDIS_ASYNC=true` depending on which mode your changes affected.

```
CONFIG_REDIS_ASYNC=true CONFIG_QUEUES_MASTER_NAME=localhost:6379/5 CONFIG_REDIS_PROXY=localhost:6379/6 time -- bundle exec rake --backtrace  bench[worker/worker_bench.rb]
```

## Check listerner performance locally

### Obtain existing keys and metric

This is useful if you later want to compare performed requests to the reported requests in porta.
Alternatively you can generate fake entries into apisonator database.

Open porta, choose a provider and get the keys through the UI.

You can use also use porta rails console.
```ruby
Account.all.pluck :org_name, :id
Account.find(2).provider_key
Account.find(2).services.first.id
Account.find(2).services.first.cinstances.take.user_key
```

To ensure the provider data is synced in apisonator, run this in porta repo:
```
PROVIDER_ID=2445584351329 bundle exec rake backend:storage:rewrite
```

### Create fake keys and metric

This approach is quicker and doesn't require porta to be running.

With ruby
```
export CONFIG_REDIS_ASYNC=false
bundle exec ruby -Ilib/ -r3scale/backend.rb <<EOF
  ThreeScale::Backend::Service.save!(provider_key: 'pk', id: '1')
  ThreeScale::Backend::Application.save(service_id: '1', id: '1', state: :active)
  ThreeScale::Backend::Application.save_id_by_key('1', 'uk', '1')
  ThreeScale::Backend::Metric.save(service_id: '1', id: '1', name: 'hits')
EOF
```

Or API:
```
curl -X PUT -u system_app:password http://localhost:3001/internal/services/1 -d '{"service": { "id": "1", "provider_key": "pk" }}'
curl -X PUT -u system_app:password http://localhost:3001/internal/services/1/applications/1 -d '{"application": { "state": "active" }}'
curl -X PUT -u system_app:password http://localhost:3001/internal/services/1/applications/1/key/uk
curl -X PUT -u system_app:password http://localhost:3001/internal/services/1/metrics/1 -d '{"metric": { "name": "hits" }}'
```

Note that the api user and password need to match your actual passwords from local apisonator environment or from the `backend-internal-api` secret in the OpenShift project.

### Run many requests with hey

This is an example command using the fake data above. You need to adjust for real keys in porta.

```
hey -z 1h -c 60 "http://localhost:3001/transactions/authrep.xml?provider_key=pk&service_id=1&user_key=uk&usage%5Bhits%5D=1"
```

## running long stress test inside OCP

Obtain proper keys or create them as described above. Then run a pod like this one in the OpenShift cluster.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend-hey-0
spec:
  restartPolicy: Never
  containers:
    - name: hey
      image: williamyeh/hey:latest
      args:
      - "-z"
      - 12h
      - "-c"
      - "60"
      - "http://backend-listener-internal/transactions/authrep.xml?provider_key=pYH6zoa2HlaWt0nj6QDg9Y0WTVjqyo&service_id=2555418011440&user_key=301e82fc483319fe89d7bb06e80b181a&usage%5Bhits%5D=1"
```
