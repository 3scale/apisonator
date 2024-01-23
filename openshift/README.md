# backend-docker Docker image

Universal backend docker image.

## some important ENV vars

This docker image uses a ENV file `.env`, you have an example file: `.env.test`, if you want to use the example file:

```
cp .env.test .env
```

Some ENV vars are set as ENVs in the Makefile, others inside the env file `.env`

**GLOBAL ENV**

`ENV_RACK` allowed values: `staging`, `production`
- `staging`: sets backend in staging mode
- `production`: sets backend in production

**WORKER ENVS**

`CONFIG_QUEUES_MASTER_NAME` allowed values: `host:port`
- Sets the host and port for connecting to a Redis server used to enqueue Resque jobs.

**LISTENER ENVS**

`CONFIG_REDIS_PROXY` allowed values: `host:port`
- Sets the host and port for connecting to a Redis (or Twemproxy) used as backend storage.

## Building

```shell
export GEMINABOX_CREDENTIALS
GEMINABOX_CREDENTIALS="geminabox_credentials"

make build
```

## Running

By default worker and listener will try to use localhost:6379 as the default redis, you can change it by editing the `.env` file and changing the value of  `CONFIG_QUEUES_MASTER_NAME` for worker mode, or `CONFIG_REDIS_PROXY` for listener mode

```shell
cp .env.test .env

make worker/listener
```

## Testing

If you have a backend deployed and want to test it:

```shell
BACKEND_ENDPOINT="backend-listener" make test-integration
```


If you want to test if the docker image is working:

```GEMINABOX_CREDENTIALS="geminabox_credentials"  make test-integration```

## Other useful commands

#### bash

```
make bash
```

# Releasing backend as part of AMP

Please run `make help` and read the comments in `Makefile` for additional options.

1. Build the image

   ```shell
   make RELEASE=ER5-pre1 release
   ```

2. Test the image

   ```shell
   make RELEASE=ER5-pre1 test
   ```

3. Tag the image

   ```shell
   make RELEASE=ER5-pre1 tag
   ```

4. Push the image

   ```shell
   make RELEASE=ER5-pre1 push
   ```

Or you can do all actions at once:

```shell
   make RELEASE=ER5-pre1 release test tag push
```

