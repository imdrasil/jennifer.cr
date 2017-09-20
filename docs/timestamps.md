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
