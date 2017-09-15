For command management Jennifer now uses [Sam](https://github.com/imdrasil/sam.cr). So in your `sam.cr` just add loading migrations and Jennifer hooks.

```crystal
require "./your_configuration_folder/*" # with requiring jennifer and her adapter
require "./migrations/*"
require "sam"
load_dependencies "jennifer"
# your another tasks here
Sam.help
```

#### Commands
Now you can use next commands:

- create database
```shell
$ crystal sam.cr -- db:create
```
- drop database
```shell
$ crystal sam.cr -- db:drop
```
- run all migrations (only new ones will be run)
```shell
$ crystal sam.cr -- db:migrate
```

- run several migrations
```shell
$ crystal sam.cr -- db:step
$ crystal sam.cr -- db:step 2
```

- create db and run all migrations (only new ones will be run)
```shell
$ crystal sam.cr -- db:setup
```
- rollback last migration
```shell
$ crystal sam.cr -- db:rollback
```
- rollback `n` migrations
```shell
$ crystal sam.cr -- db:rollback n
```
- rollback untill version `a`
```shell
$ crystal sam.cr -- db:rollback -v a
```
- generate new migration file
```shell
$ crystal sam.cr -- generate:migration your_migration_name
```
- get last migration version
```shell
$ crystal sam.cr -- db:version
```

- load schema
```shell
$ crystal sam.cr -- db:schema:load
```

#### Migration DSL

Generator will create template file for you with next name  pattern "timestamp_your_underscored_migration_name.cr". Empty file looks like this:
```crystal
class YourCamelcasedMigrationName20170119011451314 < Jennifer::Migration::Base
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
    t.reference :contact # creates field contact_id with Int type and allows null values
    t.string :street, {:size => 20, :sql_type => "char"} # creates string field with CHAR(20) db type
    t.bool :main, {:default => false} # sets false as default value
  end
```

There are next methods which represents corresponding types:

| internal alias | PostgreSQL | MySql | Crystal type |
| --- | --- | --- | --- |
| `#integer` | `int` | `int` | `Int32` |
| `#string` | `varchar(254)` | `varchar(254)` | `String` |
| `#bool` | `boolean` | `bool` | `Bool` |
| `#char` | `char` | - | `String` |
| `#float` | `real` | `float` | `Float32` |
| `#double` | `double precision` | `double` | `Float64` |
| `#short` | `smallint` | `smallint` | `Int16` |
| `#timestamp` | `timestamp` | `timestamp` | `Time` |
| `#date_time` | `datetime` | `datetime` | `Time` |
| `#blob` | `blob` | `blob` | `Bytes` |
| `#var_string` | `varchar(254)` | `varstring` | `String` |
| `#json` | `json` | `json` | `JSON::Any` |
| `#enum` | `enum` | `enum` | `String` |

Also if you use postgres array types are available as well: `Array(Int32)`, `Array(Char)`, `Array(Float32)`,  `Array(Float64)`, `Array(Int16)`, `Array(Int32)`, `Array(Int64)`, `Array(String)`.

All of them accepts additional options:

- `:sql_type` - gets exact (except size) field type;
- `:null` - represent nullable if field (by default is `false` for all types and field);
- `:primary` - marks field as primary key field (could be several ones but this provides some bugs with query generation for such model - for now try to avoid this).
- `:default` - default value for field
- `:auto_increment` - marks field to use auto increment (properly works only with `Int32` fields, another crystal types have cut functionality for it);
- `:array` - mark field to be array type (postgres only)

Also there is `#field` method which allows to directly define sql type (very suitable for snums in postgres).


To drop table just write
```crystal
drop_table(:addresses) # drops if exists
```

To alter existing table use next methods:
 - `#change_column(name, [new_name], options)` - to change column definition; postgres has slighly another implementation of this than mysql one - check source code for details;
 - `#add_column(name, type, options)` - add new column;
 - `#drop_column(name)` - drops existing column
 - `#add_index(name : String, field : Symbol, type : Symbol, order : Symbol?, length : Int32?)` - adds new index (postgres doesn't support length parameter and only support `:unique` type);
 - `#drop_index(name : String)` - drops existing index;
 - `#rename_table(new_name)` - renames table.

Also next support methods are available:
- `#table_exists?(name)`
- `#index_exists?(table, name)`
- `#column_exists?(table, name)`
- `#data_type_exists?(name)` for postgres ENUM

Here is quick example:

```crystal
def up
  change_table(:contacts) do |t|
    t.change_column(:age, :short, {default: 0})
    t.add_column(:description, :text)
    t.add_index("contacts_description_index", :description, type: :uniq, order: :asc)
  end

  change_table(:addresses) do |t|
    t.add_column(:details, :json)
  end
end

def down
  change_table(:contacts) do |t|
    t.change_column(:age, :integer, {default: 0})
    t.drop_column(:description)
  end

  change_table(:addresses) do |t|
    t.drop_column(:details)
  end
end
```

Also plain SQL could be executed as well:

```crystal
execute("ALTER TABLE addresses CHANGE street st VARCHAR(20)")
```
All changes are executed one by one so you also could add data changes here (in `up` method) but if execution of `up` method fails - `down` method will be called and all process will stop - be ready for such behavior.

To be sure that your db is up to date before run tests of your application, add `Jennifer::Migration::Runner.migrate`.

#### Enum

Now enums are supported as well but it has different implementation for adapters. For mysql is enought just write down all values:
```crystal
create_table(:contacts) do |t|
  t.enum(:gender, values: ["male", "female"])
end
```

Postgres provide much more flexible and complex behaviour. Using it you need to create it firstly:

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
