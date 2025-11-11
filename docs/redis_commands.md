# Redis Commands Required by Apisonator

This document lists all Redis commands required to run Apisonator in production. This information is useful for:
- Configuring Redis ACLs (Access Control Lists)
- Troubleshooting Redis connectivity issues
- Understanding Redis command requirements for proxy configurations
- Security auditing and compliance

## Complete Command Set

Apisonator requires the following **33 Redis commands** to operate correctly in production:

### Commands Used Directly by Apisonator (28 commands)

#### List Operations (7 commands)
- **BLPOP** - Wait for and fetch jobs from queue (worker)
- **LLEN** - Check queue length (worker)
- **LPOP** - Fetch jobs from queue (worker)
- **LPUSH** - Enqueue jobs (listener)
- **LRANGE** - Read queue contents (worker)
- **LTRIM** - Trim queue (worker)
- **RPUSH** - Enqueue jobs (listener)

#### Set Operations (7 commands)
- **SADD** - Store application keys, referrer filters, service lists (models)
- **SCAN** - Scan all keys for stats cleanup (stats cleaner)
- **SCARD** - Check if application has keys/filters (application model)
- **SISMEMBER** - Verify key membership (application model)
- **SMEMBERS** - Load application keys, referrer filters, metrics (models)
- **SREM** - Remove keys, filters (models)
- **SSCAN** - Scan sets for stats cleanup (stats cleaner)

#### String Operations (7 commands)
- **DEL** - Delete application, service, metric data (models)
- **EXISTS** - Check if application/service exists (models)
- **EXPIRE** - Set TTL on stats keys, distributed locks (stats, locks)
- **GET** - Load application, service, metric attributes (models)
- **MGET** - Batch load attributes (models)
- **SET** - Save application, service, metric data, acquire locks (models, locks)
- **SETEX** - Save with expiration (event storage, locks)

#### Sorted Set Operations (4 commands)
- **ZADD** - Store events (event storage)
- **ZCARD** - Count events (event storage)
- **ZREMRANGEBYSCORE** - Delete processed events (event storage)
- **ZREVRANGE** - List events (event storage)

#### Hash Operations (1 command)
- **HSET** - Store hash data (models)

#### Numeric Operations (2 commands)
- **INCR** - Generate event IDs (event storage)
- **INCRBY** - Aggregate stats, increment counters (stats aggregator)

### Commands Used by Dependencies (5 commands)

These commands are not called directly by Apisonator code but are required by the Redis client gem and Resque:

#### Redis Gem (2 commands)
- **SELECT**
- **ROLE**

#### Resque (3 commands)
- **LINDEX**
- **LREM**
- **LSET**

### Test-Only Commands (5 commands)

The following commands are **only used by the test suite** and are not required for production:

- **BRPOPLPUSH**
- **FLUSHDB**
- **KEYS**
- **PING**
- **TTL**

## ACL Configuration Example

If you are using Redis ACL to restrict commands, you can create a user with only these permissions:

```redis
ACL SETUSER apisonator on >your_password ~* +blpop +llen +lpop +lpush +lrange +ltrim +rpush +sadd +scan +scard +sismember +smembers +srem +sscan +del +exists +expire +get +mget +set +setex +zadd +zcard +zremrangebyscore +zrevrange +hset +incr +incrby +select +role +lindex +lrem +lset
```

For test environments, add the test-only commands:

```redis
ACL SETUSER apisonator on >your_password ~* +blpop +llen +lpop +lpush +lrange +ltrim +rpush +sadd +scan +scard +sismember +smembers +srem +sscan +del +exists +expire +get +mget +set +setex +zadd +zcard +zremrangebyscore +zrevrange +hset +incr +incrby +select +role +lindex +lrem +lset +brpoplpush +flushdb +keys +ping +ttl
```

## Version Information

This document reflects the Redis command usage as of the current version of Apisonator.
Last updated: 2025-11-10