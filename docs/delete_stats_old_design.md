# Given a Service, delete all its Stats

The number of stats from a given service A can be huge.
It is roughly estimated that there are 300K keys of stats per metric, application, user and year.
Deleting all stat keys at once is not a good idea.

The following diagram shows high level overview of the workflow being executed to delete all stats
for a given service.

![high level overview](assets/delete_stats.png)

Steps shown in the diagram are:

1. Using internal API, client starts workflow. API endpoint requires, besides some service metadata,
the list of metrics, applications, users and a time period *[from, to]*. Having this interface,
API allows partitioning at API level.
A client call this api sequentially with different subset of applications.
1. Internal API will enqueue the job. All stats deletion workflow happens offline.
1. A worker called *Partitioner* receives stats deletion job description.
It's job is to divide the long list of stats keys into sublists of not overlapped stats key set.
1. Each (small) sublist will be wrapped as a small job and enqueued for further processing by other worker.
1. A worker called *Stats Deleter* receives one of those jobs containing small sublist of stats key
1. Perform actual stats deletion operation on database in batches of keys.

Some features of the designed workflow:

* Jobs for stats deletion will be enqueued into low priority queues.
The idea is to minimize db impact and there is no rush deleting stats.
* The (small) jobs received by *Stats Deleter* are measured in number of keys.
Limiting jobs in number of keys allows measurable expected impact in db, no matter what.
DB delete operations occur in batches.
* *Partitioner* and *Stats Deleter* configuration must be designed with two goals:
  * small number of delete operations by *Stats Deleter* -> Allows worker to finish quickly the job
  and start another, probably with higher priority, job. Besides, in case of failure,
  the job to be re-done is minimized.
  * Small number of batch size per each delete operation -> Minimizes db load and allows high response times.
* Having responsive and low response times by design, that might lead to the generation of lots of stats delete jobs.
Should not be an issue.
