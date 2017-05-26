# Jennifer [![Build Status](https://travis-ci.org/imdrasil/jennifer.cr.svg)](https://travis-ci.org/imdrasil/jennifer.cr)

Another one ActiveRecord pattern realization for Crystal with grate query DSL and migration mechanism.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  jennifer:
    github: imdrasil/jennifer.cr
```

**Also** you need to choose one of existing adapters for your db: [mysql](https://github.com/crystal-lang/crystal-mysql) or [postgres](https://github.com/will/crystal-pg).

## Usage

### Configuration

Put
```crystal
require "jennifer/adapter/mysql" # for mysql
require "jennifer/adapter/postgres" # for postgres
require "jennifer" 
```

> Be attentive - adapter should be required before main staff. Only one adapter can be required at once.

This should be done before you load your application configurations (or at least models). Now configuration could be loaded from yaml file:

```crystal
Jennifer::Config.read("./spec/fixtures/database.yml", :development) 
```

Second argument represents environment and just use it as namespace key grapping values from yml.

```yaml
---
defaults : &defaults
  host: localhost
  adapter: postgres
  user: developer
  password: 1qazxsw2
  migration_files_path: ./examples/migrations

development:
  db: jennifer_develop
  <<: *defaults

test:
  db: jennifer_test
  <<: *defaults
```

Also dsl could be used:

```crystal
Jennifer::Config.configure do |conf|
  conf.host = "localhost"
  conf.user = "root"
  conf.password = ""
  conf.adapter = "mysql"
  conf.db = "crystal"
  conf.migration_files_path = "./examples/migrations"
end
```

All configs:

| config | default value |
| --- | --- |
| `migration_files_path` | `"./db/migrations"` |
| `structure_folder` | parent folder of `migration_files_path` |
| `host`| `"localhost"` |
| `logger` | `Logger.new(STDOUT)` |
| `schema` | `"public"` |
| `user` | - |
| `password` | - |
| `db` | - |
| `adapter` | - |
| `max_pool_size` | 5 |
| `initial_pool_size` | 1 |
| `max_idle_pool_size` | 1 |
| `retry_attempts` | 1 |
| `checkout_timeout` | 5.0 |
| `retry_delay` | 1.0|

#### Logging

Jennifer uses regular Crystal logging mechanism so you could specify your own logger or formatter:

```crystal
# Here is default logger configuration
Jennifer::Config.configure do |conf|
  conf.logger = Logger.new(STDOUT)

  conf.logger.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
    io << datetime << ": " << message
  end
  conf.logger.level = Logger::DEBUG
end
```

### Migration

For command management Jennifer now uses [Sam](https://github.com/imdrasil/sam.cr). So in your `sam.cr` just add loading migrations and Jennifer hooks.

```crystal
require "./your_configuration_folder/*" # with requiring jennifer and her adapter
require "./migrations/*"
load_dependencies "./", "jennifer"
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

All of them accepts additional options:

- `:sql_type` - gets exact (except size) field type;
- `:null` - represent nullable if field (by default is `false` for all types and field);
- `:primary` - marks field as primary key field (could be several ones but this provides some bugs with query generation for such model - for now try to avoid this).
- `:default` - default value for field
- `:auto_increment` - marks field to use auto increment (properly works only with `Int32` fields, another crystal types have cut functionality for it);

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

### Model

Several model examples
```crystal
class Contact < Jennifer::Model::Base
  with_timestamps
  mapping(
    id: {type: Int32, primary: true},
    name: String,
    gender: {type: String, default: "male", null: true},
    age: {type: Int32, default: 10},
    description: {type: String, null: true},
    created_at: {type: Time, null: true},
    updated_at: {type: Time, null: true}
  )

  has_many :addresses, Address
  has_many :facebook_profiles, FacebookProfile
  has_and_belongs_to_many :countries, Country
  has_and_belongs_to_many :facebook_many_profiles, FacebookProfile, join_foreign: :profile_id
  has_one :main_address, Address, {where { _main }}
  has_one :passport, Passport

  validates_inclucion :age, 13..75
  validates_length :name, minimum: 1, maximum: 15
  validates_with_method :name_check

  scope :main { where { _age > 18 } }
  scope :older { |age| where { _age >= age } }
  scope :ordered { order(name: :asc) }

  def name_check
    if @description && @description.not_nil!.size > 10
      errors.add(:description, "Too large description")
    end
  end
end

class Address < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    main: Bool,
    street: String,
    contact_id: {type: Int32, null: true},
    details: {type: JSON::Any, null: true}
  )
  validates_format :street, /st\.|street/

  belongs_to :contact, Contact

  scope :main { where { _main } }
end

class Passport < Jennifer::Model::Base
  mapping(
    enn: {type: String, primary: true},
    contact_id: {type: Int32, null: true}
  )

  validates_with [EnnValidator]
  belongs_to :contact, Contact
end

class Profile < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    login: String,
    contact_id: Int32?,
    type: String
  )

  belongs_to :contact, Contact
end

class FacebookProfile < Profile
  sti_mapping(
    uid: String
  )

  has_and_belongs_to_many :facebook_contacts, Contact, foreign: :profile_id
end

class TwitterProfile < Profile
  sti_mapping(
    email: String
  )
end

class Country < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    name: String
  )

  validates_exclusion :name, ["asd", "qwe"]
  validates_uniqueness :name

  has_and_belongs_to_many :contacts, Contact
end
```

`mapping` macros stands for describing all model attributes. If field has no extra parameter, you can just specify name and type (type in case of crystal language): `field_name: :Type`. But you can use tuple and provide next parameters:

| argument | description |
| --- | --- |
| `:type` | crystal data type (don't use question mark - for now you can use only `:null` option) |
| `:primary` | mark field as primary key (default is `false`) |
| `:null` | allows field to be `nil` (default is `false` for all fields except primary key |
| `:default` | default value which be set during creating **new** object |
| `:getter` | if getter should be created (default - `true`) |
| `:setter` | if setter should be created (default - `true`) |

> By default expected that all fields are defined in model. It that is not true you should to pass `false` as second argument and override `::field_count` method to represent correct field count.

It defines next methods:

| method | args | description |
| --- | --- | --- |
| `#initialize` | Hash(String \| Symbol, DB::Any), NamedTuple, MySql::ResultSet | constructors |
| `::field_count`| | number of fields |
| `::field_names`| | all fields names |
| `#{{field_name}}` | | getter |
| `#{{field_name}}_changed?` | | represents if field is changed |
| `#{{field_name}}!` | | getter with `not_nil!` if `null: true` was passed |
| `#{{field_name}}=`| | setter |
| `::_{{field_name}}` | | helper method for building queries |
| `#{{field_name}}_changed?` | | shows if field was changed |
| `#changed?` | | shows if any field was changed | 
| `#primary` | | value of primary key field |
| `::primary` | | returns criteria for primary field (query dsl) |
| `::primary_field_name` | | name of primary field |
| `::primary_field_type` | | type of primary key |
| `#new_record?` | | returns `true` if record has `nil` primary key (is not stored to db) |
| `::create` | `Hash(String \| Symbol, DB::Any)`, `NamedTuple` | creates object, stores it to db and returns it |
| `::create!` | `Hash(String \| Symbol, DB::Any)`, `NamedTuple` | creates object, stores it to db and returns it; otherwise raise exception |
| `::build` | `Hash(String \| Symbol, DB::Any), NamedTuple` | builds object |
| `::create` | `Hash(String \| Symbol, DB::Any)`, `NamedTuple` | builds object from hash and saves it to db with all callbacks |
| `::create!` | `Hash(String \| Symbol, DB::Any)`, `NamedTuple` | builds object from hash and saves it to db with callbacks or raise exception |
| `#save` | | saves object to db; returns `true` if success and `false` elsewhere |
| `#save!` | | saves object to db; returns `true` if success or rise exception otherwise |
| `#to_h` | | returns hash with all attributes |
| `#to_str_h` | | same as `#to_h` but with String keys |
| `#attribute` | `String \| Symbol` | returns attribute value by it's name |
| `#attributes_hash` | | returns `to_h` with deleted `nil` entries |
| `#changed?` | | check if any field was changed |
| `#set_attribute` | `String \| Symbol`, `DB::Any` | sets attribute by given name |
| `#attribute` | `String \| Symbol` | returns attribute value by it's name |

Automatically model is associated with table with underscored pluralized class name, but special name can be defined using `::table_name` method in own body before using any relation (`::singular_table_name` - for singular variant).

#### STI

Singl table inheritance could be used in next way:
```crystal
class Profile < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    login: String,
    contact_id: Int32?,
    type: String
  )

  belongs_to :contact, Contact
end

class FacebookProfile < Profile
  sti_mapping(
    uid: String
  )

  has_and_belongs_to_many :facebook_contacts, Contact, foreign: :profile_id
end

class TwitterProfile < Profile
  sti_mapping(
    email: String
  )
end
```

Subclass extends superclass definition with new fields and use string fild `type` to indentify itself.

> Now `Profile.all` will return objects of `Profile` class not taking into account `type` field and will raise exception of even zomby process if superclass doesn't override `::field_count`.

#### Prepared queries (scopes)

Also you can specify prepared query statement.

```crystal
scope :query_name { where { c("some_field") > 10 } }
scope :query_with_arguments { |a, b| where { (c("f1") == a) && (c("f2").in(b) } }
```

As you can see arguments are next:

- scope (query) name
- block to be executed in query contex (any query part could be passed: join, where, having, etc.)

Also they are chainable, so you could do:

```crystal
ModelName.all.where { _some_field > 1 }
         .query_with_arguments("done", [1,2])
         .order(f1: :asc).no_argument_query
```

#### Relations

There are 4 types of relations: has_many, has_and_belongs_to_many, belongs_to and has_one. All of them have same semantic but generate slightly different methods.

They takes next arguments:

- relation name
- target class
- `request` - additional request (will be used inside of where clause) - optional
- `foreign` - name of foreign key - optional; by default use singularized table name + "_id"
- `primary` - primary field name - optional;  by default it uses default primary field of class.

has_and_belongs_to_many also accepts next 2 arguments and use regular arguments silghtly in another way:
- `join_table` - join table name; be default relation table names in alphabetic order joined by underscore is used
- `join_foreign` - foreign key for current model (left foreign key of join table)
- `foreign` - used as right foreign key
- `primary` - used as primary field of current table; for now it properly works only if both models in this relation has primary field named `id`

All relation macroses provide next methods:

- `#{{relation_name}}` - cache relation object (or array of them) and returns it;
- `#{{relation_name}}_reload` - reload relation and returns it;
- `#{{relation_name}}_query` - returns query which is used to get objects of this object relation entities form db.
- `#remove_{{relation_name}}` - removes given object from relation
- `#add_{{relation_name}}` - adds given object to relation or builds it from has and adds

This allows dynamically adds objects to relations with automacially settting foreign id:

```crystal
contact = Contact.all.find!
contact.add_addresses({:main => true, :street => "some street", :details => nil})

address = contact.addresses.last
contact.remove_addresses(address)
```

`belongs_to` and `has_one` add extra method `#relation_name!` which also adds assertion for `nil`.

#### Validations

For validation purposes is used [accord](https://github.com/neovintage/accord) shard. Also there are several general macrosses for declaring validations:
- `validates_with_method(*names)` - accepts method name/names
- `validates_inclusion(field, value)` - checks if `value` includes `@{{field}}`
- `validates_exclusion(field, value)` - checks if `value` excludes `@{{field}}`
- `validates_format(field, format)` - checks if `{{format}}` matches `@{{field}}`
- `validates_length(field, **options)` - check `@{{field}}` size; allowed options are: `:in`, `:is`, `:maximum`, `:minimum`
- `validates_uniqueness(field)` - check if `@{{field}}` is unique

If record is not valid it will not be saved.

#### Callbacks

There are next macrosses for defining callbacks:
- `before_save`
- `after_save`
- `before_create`
- `after_create`
- `after_initialize`
- `before_destroy`

They accept method names.

#### Timestamps

`with_timestamps` macros adds callbacks for `created_at` and `updated_at` fields update.

#### Destroy

To destroy object use `#delete` (is called withoud callback) or `#destroy`. To destroy several objects by their ids use class method:

```crystal
ids = [1, 20, 18]
Contact.destroy(ids)
Address.delete(1)
Country.delete(1,2,3)
```

#### Update

There are several ways which allows to update object. Some of them were mentioned in mapping section. There are few extra methods to do this:
- `#update_column(name, value)` - sets directly attribute and store it to db without any callback
- `#update_columns(values)` - same for several ones
- `#update_attributes(values)` - just set attributes
- `#set_attribute(name, value)` - set attribute by given name

### Query DSL

My favorite part. Jennifer allows you to build lazy evaluated queries with chaining syntax. But some of them could be only at the and of a chain (such as `#fisrt` or `#pluck`). Here is a list of all dsl methods:

#### Find

Object could be retrieved by id using `find` (returns `T?`) and `find!` (returns `T` or raise `RecordNotFound` exception) methods.

```crystal
Contact.find!(1)
```

#### Where

`all` retrieves everything (only at the beginning; creates empty request)
```crystal
Contact.all
```

Specifying where clause is really flexible. Method accepts block which represents where clause of request (or it's part - you can chain several `where` and they will be concatenated using `AND`).

To specify field use `c` method which accepts string as field name. As I've mentioned after declaring model attributes, you can use their names inside of block: `_field_name` if it is for current table and `ModelName._field_name` if for another model. Also there you can specify attribute of some model or table using underscores: `_some_model_or_table_name__field_name` - model/table name is separated from field name by "__". You can specify relation in space of which you want to declare condition using double _ at the beginning and block. Several examples:
```crystal
Contact.where { c("id") == 1 }
Contact.where { _id == 1 }
Contact.all.join(Address) { Contact._id == _contact_id }
Contact.all.relation(:addresses).where { __addresses { _id > 1 } } 
```

Also you can use `primary` to mention primary field:

```crystal
Passport.where { primary.like("%123%") }
```

Supported operators:

| Operator | SQL variant |
| --- | --- |
| `==` | `=` |
| `!=` |`!=` |
| `<` |`<` |
| `<=` |`<=` |
| `>` |`>` |
| `>=` |`>=` |
| `=~` | `REGEXP`, `~` |
| `&` | `AND` |
| `|` | `OR` |

And operator-like methods:

| Method | SQL variant |
| --- | --- |
| `regexp` | `REGEXP`, `~` (accepts `String`) |
| `not_regexp` |`NOT REGEXP` |
| `like` | `LIKE` |
| `not_like` | `NOT LIKE` |
| `is` | `IS` and provided value |
| `not` | `NOT` and provided value (or as unary operator if no one is given) |
| `in` | `IN` |

To specify exact sql query use `#sql` method:
```crystal
# it behaves like regular criteria
Contact.all.where { sql("age > ?",  [15]) & (_name == "Stephan") } 
```

Query will be inserted "as is". Usage of `#sql` allows to use nested plain request.

**Tips**

- all regexp methods accepts string representation of regexp
- use parenthesis for binary operators (`&` and `|`)
- `nil` given to `!=` and `==` will be transformed to `IS NOT NULL` and `IS NULL`
- `is` and `not` operator accepts next values: `:nil`, `nil`, `:unknown`, `true`, `false`

At the end - several examples:

```crystal
Contact.where { (_id > 40) & _name.regexp("^[a-d]") }

Address.where { _contact_id.is(nil) }
```

#### Select

Raw sql for `SELECT` clause could be passed into `#select` method. This have highest priority during forming this query part.

```crystal
Contact.all.select("COUNT(id) as count, contacts.name").group("name")
       .having { sql("COUNT(id)") > 1 }.pluck(:name)
```

#### From

Also you can provide subquery to specify FROM clause (but be carefull with source fields during result retriving and mapping to objects)

```crystal
Contact.all.from("select * from contacts where id > 2")
Contacts.all.from(Contact.where { _id > 2 })
```

#### Delete and Destroy

For now they both are the same - creates delete query with given conditions. `destroy` firstly loads objects and run callbacks and then calls delete on each.

It can be only at the end of chain.

```crystal
Address.where { _main.not }.delete
```

#### Joins

To join another table you can use `join` method passing model class or table name (`String`) and join type (default is `:inner`).
```crystal
field = "contact_id"
table = "passports"
Contact.all.join(Address) { Contact._id == _contact_id }.join(table) { c(field) == _id }
```

Query, built inside of block, will passed to `ON` section of `JOIN`. Current context of block is joined table.

Also there is two shortcuts for left and right joins:

```crystal
Contact.all.left_join(Address) { _contacts__id == _contact_id }
Contact.all.right_join("addresses") { _contacts__id == c("contact_id") }
```

> For now Jennifer provide manual aliasing as second argument for `#join` and automatic when using `#includes` and `#with` methods. For details check out the code. 

#### Relation

To join model relation (has_many, belongs_to and has_one) pass it's name and join type:

```crystal
Contact.all.relation("addresses").relation(:passport, type: :left)
```

#### Includes

To preload some relation use `includes` and pass relation name:

```crystal
Contact.all.includes("addresses")
```

If there are several includes with same table - Jennifer will auto alias tables.

#### Group

```crystal
Contact.all.group("name", "id").pluck(:name, :id)
```

`#group` allows to add columns for `GROUP BY` section. If passing arguments are tuple of strings or just one string - all columns will be parsed as current table columns. If there is a need to group on joined table or using fields from several tables use next:

```crystal
Contact.all.relation("addresses").group(addresses: ["street"], contacts: ["name"])
       .pluck("addresses.street", "contacts.name")
```

 Here keys should be *table names*.

#### Having

```crystal
Contact.all.group("name").having { _age > 15 }
```

`#having` allows to add `HAVING` part of query. It accepts block same way as `#where` does.

#### Exists

```crystal
Contact.where { _age > 42 }.exists? # returns true or false
```

`#exists?` check is there is any record with provided conditions. Can be only at the end of query chain - it hit the db.

#### Distinct

```crystal
Contant.all.distinct("age") # returns array of ages (Array(DB::Any | Int16 | Int8))
```

`#distinct` retrieves from db column values without repeats. Can accept column name and as optional second parameter - table name. Can be only as at he end of call chain - hit the db.

#### Aggregation

There are 2 types of aggregation functions: ones which are orking without GROUP clause and returns single values (e.g. `max`, `min`, `count`) and ones, working with GROUP clause and returning array of values.

#### Max

```crystal
Contact.all.max(:name, String)
```

#### Min

```crystal
Contact.all.min(:age, Int32)
```

#### Avg

```crystal
Contact.all.avg(:age, Float64) # mysql specific
Contact.all.avg(:age, PG::Numeric) # Postgres specific
```

#### Sum

```crystal
Contact.all.sum(:age, Float64) # mysql specific
Contact.all.sum(:age, Int64) # postgre specific
```

#### Count

```crystal
Contact.all.count
```

#### Group Max

```crystal
Contact.all.group(:gender).group_max(:age, Int32)
```

#### Group Min

```crystal
Contact.all.group(:gender).group_min(:age, Int32)
```

#### Group Avg

```crystal
Contact.all.avg(:age, Float64) # mysql specific
Contact.all.avg(:age, PG::Numeric) # Postgres specific
```

#### Group Sum

```crystal
Contact.all.group(:gender).group_sum(:age, Float64) # mysql specific
Contact.all.group(:gender).group_sum(:age, Int64) # postgre specific
``` 

#### Pagination

For now you can only specify `limit` and `offset`:

```crystal
Contact.all.limit(10).offset(10)
```

#### Order

You can specifies orders to sort:
```crystal
Contact.all.order(name: :asc, id: "desc")
```

It accepts hash as well.

#### Update

You can provide hash or named tuple with new field values:
```crystal
Contact.all.update(age: 1, name: "Wonder")
```

Will not trigers any callback.

#### Eager load

As was said Jennifer provide lazy query evaluation  so it will be performed only after trying to access to element from collection (any array method - it implements Enumerable). Also you can extract first entity via `first`. If you are sure that at least one entity in db satisfies you query you can call `#first!`.

To extract only some fields rather then entire objects use `pluck`:

```crystal
Contact.all.pluck(:id, "name")
```

It returns array of values if only one field was given and array of arrays if more. It accepts raw sql arguments so be care when using this with joining tables with same field names. But this allows to retrieve some custom data from specified select clause.

```crystal
Contact.all.select("COUNT(id) as count, contacts.name").group("name")
       .having { sql("COUNT(id)") > 1 }.pluck(:count)
```

To load relations using same query joins needed tables (yep you should specify join on condition by yourself again) and specifies all needed relations in `with` (relation name not table).

```crystal
Contact.all.left_join(Address) { _contacts__id == _contact_id }.with(:addresses)
```

#### Transaction

Transaction mechanism provides block-like syntax:

```crystal
Jennifer::Adapter.adapter.transaction do |tx|
  Contact.create({:name => "Chose", :age => 20})
end
```

If any error was raised in block transaction will be rollbacked. To rollback transaction raise `DB::Rollback` exception.

Transaction lock connection for current fiber avoiding grepping new one from pool.

#### Truncation

To truncate entire table use:
```crystal
Jennifer::Adapter.adapter.truncate("contacts")
# or
Jennifer::Adapter.adapter.truncate(Contact)
```

This functionality could be useful to clear db between test cases.

### Important restrictions

- sqlite3 has a lot of limitations so it's support will be added not soon

### Test

The fastest way to rollback all changes in DB after test case - transaction. So add:
```crystal
Spec.before_each do
  Jennifer::Adapter.adapter.begin_transaction
end

Spec.after_each do
  Jennifer::Adapter.adapter.rollback_transaction
end
```

to your `spec_helper.cr`. Also just regular deleting or truncation could be used but transaction provide 15x speed up (at least for postgres; mysql gets less impact).

> This functions can be safely used only under test environment.

## Development

There are still a lot of work to do. Tasks for next versions:

- [ ] add SQLite support
- [ ] increase test coverage to acceptable level
- [ ] add json operators
- [ ] add PG::Array support
- [ ] add possibility for `#group` accept any sql string
- [ ] add polymorphic associations
- [ ] add through to relations
- [ ] add subquery support
- [ ] add join table option for all relations
- [ ] refactor many-to-many relation
- [ ] add seeds
- [ ] rewrite tests to use minitest
- [ ] add self documentation
- [ ] add views support (materialized as well)

## Development

Before development create db user (information is in /spec/config.cr file), run
```shell
$ crystal example/migrate.cr -- db:setup
```

Support both MySql and PostgreSQL are critical. By default postgres are turned on. To run tests with mysql use next:
```shell
$ DB=mysql crystal spec
```

## Contributing

1. [Fork it]( https://github.com/imdrasil/jennifer.cr/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

Please ask me before starting work on smth.

Also if you want to use it in your application (for now shard is almost ready for use in production) - ping me please, my email you can find in my profile.

To run tests use regular `crystal spec`. All migrations is under `./examples/migrations` directory.

## Contributors

- [imdrasil](https://github.com/imdrasil) Roman Kalnytskyi - creator, maintainer
