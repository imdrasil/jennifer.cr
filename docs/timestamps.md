# Timestamps

`with_timestamps` macros adds callbacks for `created_at` and `updated_at` fields update. But now they still should be defined in the mapping manually:

```crystal
class MyModel < Jennifer::Model::Base
  with_timestamps

  mapping(
    id: Primary64,
    created_at: {type: Time, null: true},
    updated_at: {type: Time, null: true}
  )
end
```

`created_at` field is populated with current time when corresponding record is stored to the database. `updated_at` - whenever record is updated (the way that callbacks are invoked).
