# Views

> For now any type of view should have defined primary key as well as model.

## Non Materialized

Both adapters support non materialized view. Here is an example of migration:

```crystal
class AddView20170916095004544 < Jennifer::Migration::Base
  def up
    create_view(:male_contacts, Jennifer::Query["contacts"].where { _gender == sql("'male'") })
  end

  def down
    drop_view(:male_contacts)
  end
end
```

Second argument of `#create_view` describes query which will  be used to retrieve data.

**Important restriction**: any prepared argument is not allowed for now - all arguments should be escaped by your own.

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
    id:     Primary64,
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

Also all defined mapping properties are accessible via `COLUMNS_METADATA` constant and `.columns_tuple` method.

## Materialized

> Materialized view is partially supported only by Postgres adapter. MySQL doesn't provide support of materialized view at all. This could be simulated only by using common table.

Common migration for adding materialized view looks like this:

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

As for non materialized view all arguments should be escaped explicitly as well.

Example of defining created before materialized view looks like:

```crystal
class FemaleContact < Jennifer::Model::Materialized
  mapping({
    id:   Primary64,
    name: String?,
  }, false)
end
```

To refresh content of materialized view use:

```crystal
FemaleContact.refresh
```
