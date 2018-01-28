# Timestamps and Time

`with_timestamps` macros adds callbacks for `created_at` and `updated_at` fields update. But now they still should be mentioned in mapping manually:

```crystal
class MyModel < Jennifer::Model::Base
  with_timestamps
  mapping(
    id: { type: Int32, primary: true },
    created_at:  {type: Time, null: true},
    updated_at:  {type: Time, null: true}
  )
end
```

### Time

Any model or view `Time` attribute will be automatically converted from local time zone (which could be set using `Jennifer::Config.local_time_zone_name=`) to UTC and converted back during reading from the DB. Also during querying the db all `Time` arguments will be converted same way as well. Only `Jennifer::Record` time attributes is not automatically converted from UTC to local time during loading from the result set.
