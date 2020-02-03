# Delete stats

When Apisonator receives a request from Porta to delete the stats for a specific
service, it does not delete them right away. The reason is that there are some
design decisions taken in Apisonator that make it hard to delete all the stats
keys associated with a service in an efficient way.

Instead of deleting those stats keys automatically, Apisonator stores the
service IDs in Redis so that their stats can be deleted later. There's a rake
task to do that, `stats:cleanup`. To run it, just send the Redis servers as a
parameter like this, separated by spaces:
```
bundle exec rake stats:cleanup["127.0.0.1:9998 127.0.0.1:9999"]
```

There's an optional second parameter that controls logging. When enabled, the
task will print all the key-values that were deleted. It prints one per line and
separates the key from its value with a space. To enable logging:
```
bundle exec rake stats:cleanup["127.0.0.1:9998 127.0.0.1:9999",true]
```

Please note that if you are using a proxy like Twemproxy, you cannot include its
URL in the above command. This rake task only works with URLs redis servers.
Also, if you are using a sharded Redis deployment, make sure to include all the
shards in the command to delete the stats keys from all of them.

If you are a contributor or are interested in the design decisions behind this
feature, please check the `Backend::Stats::Cleaner` class.
