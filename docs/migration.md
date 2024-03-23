# Migration

## DSL

Generator will create template file for you with next name  pattern "timestamp_your_underscored_migration_name.cr". Empty file looks like this:

```crystal
class YourCamelCasedMigrationName < Jennifer::Migration::Base
  def up
  end

  def down
  end
end
```

`up` method is needed for placing your db changes there, `down` - for reverting your changes back.

Regular example for creating table:

```crystal
create_table(:addresses) do |t|
  # creates field contact_id with Int type, allows null values and creates foreign key
  t.reference :contact

  t.string :street, {:size => 20, :sql_type => "char"} # creates string field with CHAR(20) db type
  t.bool :main, {:default => false} # sets false as default value
end
```

There are next methods which presents corresponding types:

| Method | PostgreSQL | MySql | Crystal type |
| --- | --- | --- | --- |
| `#integer` | `int` | `int` | `Int32` |
| `#short` | `SMALLINT` | `SMALLINT` | `Int16` |
| `#bigint` | `BIGINT` | `BIGINT` | `Int64` |
| `#tinyint` | - | `TINYINT` | `Int8` |
| `#float` | `real` | `float` | `Float32` |
| `#double` | `double precision` | `double` | `Float64` |
| `#numeric` | `NUMERIC` | - | `PG::Numeric` |
| `#decimal` | `DECIMAL` | `DECIMAL` | `PG::Numeric` (pg); `Float64` (mysql) |
| `#string` | `varchar(254)` | `varchar(254)` | `String` |
| `#char` | `char` | - | `String` |
| `#text` | `TEXT` | `TEXT` | `String` |
| `#bool` | `boolean` | `bool` | `Bool` |
| `#timestamp` | `timestamp` | `datetime` | `Time` |
| `#date_time` | `timestamp` | `datetime` | `Time` |
| `#date` | `date` | `date` | `Time` |
| `#blob` | `blob` | `blob` | `Bytes` |
| `#json` | `json` | `json` | `JSON::Any` |
| `#enum` | - | `ENUM` | `String` |

In Postgres enum type is defined using custom user datatype which also is mapped to the `String`.

PostgreSQL specific datatypes:

| Method | Datatype | Type |
| --- | --- | --- |
| `#oid` | `OID` | `UInt32` |
| `#jsonb` | `JSONB` | `JSON::Any` |
| `#xml` | `XML` | `String` |
| `#blchar` | `BLCHAR` | `String` |
| `#uuid` | `UUID` | `UUID` |
| `#timestampz` | `TIMESTAMPZ` | `Time` |
| `#point` | `POINT` | `PG::Geo::Point` |
| `#lseg` | `lseg` | `PG::Geo::LineSegment` |
| `#path` | `PATH` | `PG::Geo::Path` |
| `#box` | `BOX` | `PG::Geo::Box` |
| `#polygon` | `POLYGON` | `PG::Geo::Polygon` |
| `#line` | `LINE` | `PG::Geo::Line` |
| `#circle` | `CIRCLE` | `PG::Geo::Circle` |

Also if you use postgres array types are available as well: `Array(Int32)`, `Array(Char)`, `Array(Float32)`,  `Array(Float64)`, `Array(Int16)`, `Array(Int32)`, `Array(Int64)`, `Array(String)`, `Array(Time)`, `Array(UUID)`. Currently only plain (1 dimensional) arrays are supported. Also take into account that to be able to use `Array(String)` you need to use `text :my_column, {:array => true}` in your migration.

All those methods accepts additional options:

- `:sql_type` - gets exact (except size) field type;
- `:null` - present nullable if field (by default is `false` for all types and field);
- `:primary` - marks field as primary key field (could be several ones but this provides some bugs with query generation for such model - for now try to avoid this).
- `:default` - default value for field
- `:auto_increment` - marks field to use auto increment (properly works only with `Int32 | Int64` fields, another crystal types have cut functionality for it);
- `:array` - mark field to be array type (postgres only)

Also there is `#field` method which allows to directly define SQL type.

To define reference to other table you can use `#reference`:

```crystal
create_table :pictures do |t|
  t.reference :user
  t.reference :attachable, { :polymorphic => true } # for polymorphic relation
end
```

For more details about this and other methods see [`Jennifer::Migration::TableBuilder::CreateTable`](https://imdrasil.github.io/jennifer.cr/latest/Jennifer/Migration/TableBuilder/CreateTable.html)

To drop table just write:

```crystal
drop_table(:addresses)
```

To create materialized view (postgres only):

```crystal
create_materialized_view("female_contacts", Contact.all.where { _gender == "female" })
```

And to drop it:

```crystal
drop_materialized_view("female_contacts")
```

To alter existing table use next methods:

 - `#change_column` - to change column definition;
 - `#add_column` - adds new column;
 - `#drop_column` - drops existing column;
 - `#add_index` - adds new index;
 - `#drop_index` - drops existing index;
 - `#add_foreign_key` - adds foreign key constraint;
 - `drop_foreign_key` - drops foreign key constraint;
 - `#rename_table` - renames table.

 For more details about this and other methods see [`Jennifer::Migration::TableBuilder::CreateTable`](https://imdrasil.github.io/jennifer.cr/latest/Jennifer/Migration/TableBuilder/ChangeTable.html)

Also next support methods are available:

- `#table_exists?`
- `#index_exists?`
- `#column_exists?`
- `#foreign_key_exists?`
- `#enum_exists?` (for postgres ENUM only)
- `#material_view_exists?`

Here is a quick example:

```crystal
def up
  change_table(:contacts) do |t|
    t.change_column(:age, :short, {:default => 0})
    t.add_column(:description, :text)
    t.add_index(:description, type: :uniq, order: :asc)
  end

  change_table(:addresses) do |t|
    t.add_column(:details, :json)
  end
end

def down
  change_table(:contacts) do |t|
    t.change_column(:age, :integer, {:default => 0})
    t.drop_column(:description)
  end

  change_table(:addresses) do |t|
    t.drop_column(:details)
  end
end
```

Also plain SQL could be executed as well:

```crystal
exec("ALTER TABLE addresses CHANGE street st VARCHAR(20)")
```

All changes are executed one by one so you also could add data changes here (in `#up` and/or `#down`).

#### Enum

Now enums are supported as well but each adapter has own implementation. For mysql is enough just write down all values:

```crystal
create_table(:contacts) do |t|
  t.enum(:gender, ["male", "female"])
end
```

Postgres provides much more flexible and complex behavior. Using it you need to create enum firstly:

```crystal
create_enum(:gender_enum, ["male", "female"])

create_table(:contacts) do |t|
  t.string :name, {:size => 30}
  t.integer :age
  t.field :gender, :gender_enum
  t.timestamps
end

change_enum(:gender_enum, {:add_values => ["unknown"]})
change_enum(:gender_enum, {:rename_values => ["unknown", "other"]})
change_enum(:gender_enum, {:remove_values => ["other"]})
```

For more details check source code and PostgreSQL docs.

## Micrate

If it is more convenient to you to store migrations in a plain SQL it is possible to use [micrate](https://github.com/amberframework/micrate) together with Jennifer. To do so you need to:
- add it to you dependencies

```yml
# shard.yml
dependencies:
  micrate:
    github: "amberframework/micrate"
    version: "= 0.15.0"
```
- add an override for a `crystal-db` to enforce latest version

```yml
# shard.override.yml
dependencies:
  db:
    github: crystal-lang/crystal-db
    version: ~> 0.11.0
```

- ensure your Jennifer configuration has `pool_size` set to at least 2
- add `micrate.cr` file at the root (or any other convenient place) of your project with the following content:

```crystal
require "micrate"
# Load here the part your your app responsible for Jennifer initialization
# require "./config/db.cr"

# These overrides are required to specify custom `db_dir`
module Micrate
  # Add here the path from your app root to the directory with `migration` folder
  # inside
  def self.db_dir
    "db"
  end

  private def self.migrations_by_version
    Dir.entries(migrations_dir)
      .select { |name| File.file?(File.join(migrations_dir, name)) }
      .select { |name| /^\d+_.+\.sql$/ =~ name }
      .map { |name| Migration.from_file(name) }
      .index_by { |migration| migration.version }
  end
end

Micrate::DB.connection_url = Jennifer::Adapter.default_adapter.connection_string(:db)
Micrate::Cli.run
```

After this all migration files located in the specified directory is accessible for Micrate and you can use commands like

```sh
$ crystal micrate.cr -- up
```

## Running migration

The most convenient way to apply written migrations is using Sam task. Sam file is created automatically after installation but you need to modify it to load all necessary code (configurations, migrations) and library's predefined tasks.
