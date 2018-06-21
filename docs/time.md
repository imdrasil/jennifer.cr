# Time

Any model or view `Time` attribute will be automatically converted from local time zone (which could be set using `Jennifer::Config.local_time_zone_name=`) to UTC and converted back during reading from the DB. Also during querying the db all `Time` arguments will be converted same way as well. Only `Jennifer::Record` time attributes is not automatically converted from UTC to local time during loading from the result set.

Local time could be set using:

```crystal
Jennifer::Config.config do |conf|
  # default is one stored in TZ env variable or UTC if absent
  conf.local_time_zone_name = "Etc/GMT+1"
end
```

Jennifer use own default time zone, so `Time.zone.now` still uses it's own default zone. If you need same time zone for this case as well - just assign it as well or make assignment of default TimeZone zone instead of setting it to the Jennifer itself:

```crystal
TimeZone::Zone.default = "Etc/GMT+1"

Jennifer::Config.config do |conf|
  # ...
  # this isn't needed now
  # conf.local_time_zone_name = "Etc/GMT+1"
end
```
