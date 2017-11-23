# Views

> For now any type of view should have defined primary key as well as model

## Non Materialized

Both adapters support non materialized view. Here is an example of migration:

```crystal
class AddView20170916095004544 < Jennifer::Migration::Base
  def up
    create_view(:male_contacts, Jennifer::Query["contacts"].where { sql("gender = 'male'") })
  end

  def down
    drop_view(:male_contacts)
  end
end
```

Second argument of `#create_view` describes query which will  be used to retrieve data. 

**Importent restriction**: any prepared argument is not allowed for now - any argument should be escaped by your own.

```crystal
# bad
create_view(:male_contacts, Jennifer::Query["contacts"].where { _gender == "male" })

# good
create_view(:male_contacts, Jennifer::Query["contacts"].where { sql("gender = 'male'") })
create_view(:male_contacts, Jennifer::Query["contacts"].where { _gender == sql("male") })
```

There is an example of defining view:
```crystal
class MaleContact < Jennifer::View::Base
  mapping({
    id:     Primary32,
    name:   String,
    gender: String,
    age:    Int32,
  }, false)

  scope :main { where { _age < 50 } }
  scope :older { |age| where { _age >= age } }
  scope :johny, JohnyQuery
end
```

All regular model mapping functionality are also available for views (except any functionality for deleting, updating or creating new view objects). Any scoping functionality is allowed as well. Only `after_initialize` callback is allowed. STI is not supported.

## Materialized

> Materialized view is partially supported only by postgre adapter. MySQL doesn't provide support of materiazed view at all - only via simulating using regualr table.

Regular migration for adding materialized view looks like this:

```crystal
class AddMaterializedView20170829000433679 < Jennifer::Migration::Base
  VIEW_NAME = "female_contacts"

  def up
    create_materialized_view(
      VIEW_NAME,
      Contact.all.where { _gender == sql("'female'") }
    )
  end

  def down
    drop_materialized_view(VIEW_NAME)
  end
end
```
As for non materialized view here all arguments should be escaped explicitly as well.

> Until 0.5.0 source could be represented as stringgified raw sql, but this will be removed.

For defining materialized view `Jennfer::Model::Base` superclass should be used. So example of defining created before materialized view looks like:

```crystal
class FemaleContact < Jennifer::Model::Base
  mapping({
    id:   Primary32,
    name: String?,
  }, false)
end
```

Because of using `Model::Base` you are able to use some functionality of model (except deleting, creating and updating entities).

All features of `%mapping` is supported as well.

To refresh content of materialized view use:

```crystal
Jennifer::Adapter.adapter.refresh_materialized_view("materialized_view_name")
```