# Time

Any `Time` value is automatically converted from it's time zone to UTC when is passed to database. This includes both model fields downstreaming to a database and any query parameter of `Time` class. This means when record is saved it's `created_at` field is converted from it's time zone (for instance `Europe/Kyiv`) to UTC. This also works when you use time parameters in your queries:

```crystal
Book.where { _publication_date < Time.local(2021, 10, 10, 20, location: Jennifer::Config.local_time_zone) }
# SELECT books.* FROM books where books.publication_date < '2021-10-10 17:00:00'
```

To pass time value into database request *as-is* - use UTC:

```crystal
Book.where { _publication_date < Time.utc(2021, 10, 10, 20) }
```

It is important to notice that column values are converted back to application time zone (set by `Jennifer::Config.local_time_zone_name=`) when are read from a database. So in both cases `User.all.pluck(:created_at)` and `User.first.created_at` time object will be converted from UTC to configured time zone.

Local time could be set using:

```crystal
Jennifer::Config.config do |conf|
  conf.local_time_zone_name = "Etc/GMT+1"
end
```

By default is used local time zone.

It is possible to turn off time zone converting logic entirely by setting `Jennifer::Config.time_zone_aware_attributes` to `false`. In this case all time objects will be passed to database without converting to UTC (as "wall clock" time). When time is read from a database `Jennifer::Config.local_time_zone` as time zone.

If only specific column should ignore time converting logic you can specify `time_zone_aware: false` option for it in model mapping.

```crystal
class Book < Jennifer::Model::Base
  mapping(
    # ...
    publishing_date: { type: Time, time_zone_aware: false }
  )
end
```

It is important to notice that in this case time zone converting will be omitted only when model instance is read from a database or is written to it. In other words `Book.all.pluck(:publishing_date)` in this case will perform time zone converting.
