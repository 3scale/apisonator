## How do Utilization Alerts work?

Utilization alerts work in a way that surprises some users, typically wondering
why a specific utilization alert has not been notified. Here is a description of
how they work so that users can understand why that is the case.

### Utilization percentages

Apisonator emits alerts to the administrative instance for traffic crossing
the following utilization percentage of an application _if configured to do so_:

0, 50, 80, 90, 100, 120, 150, 200, 300

At the time when utilization percentage is computed, if trafic has crossed 2 or more utilization percentages (e.g 90, 100), an alert is emitted only for the largest utilization percentage level ( eg 100). Alert for the smaller utilization percentages that have also been crossed (eg 90) will be skipped but maybe emitted later.

However, only one alert percentage is to be notified in any given 24h period.


### Alert notification

Alerts are only sent **once** in any given 24 hours period for each application and
utilization percentage regardless of the period for which the utilization
percentage was computed.

This means that once a configured alert is emitted for a particular application,
such as 120% utilization for any period (ie. minute), no alert will be emitted
for that particular application and utilization level for the next 24 hours,
even if the utilization that would reach 120% would be applying to a different
period (ie. hour), or even if the alert would be emitted for a different metric.

If, however, the utilization percentage would have not been notified in the
previous 24 hours, such as 150, then it is notified.

### Issues

This behaviour is surprising to users because they might expect an alert
notified the last day to be "forgotten" by the next day even though 24h have not
really elapsed.

There is also the additional issue that alerts that could not be sent are stored
for sending later on, but the code requires another actual alert to be generated
in order for those pending alerts to be sent. This is usually not a big deal but
still has potential for edge cases to behave very weirdly.
