# Mapping

Several model examples

```crystal
class Contact < Jennifer::Model::Base
  with_timestamps
  mapping(
    id: Primary32, # same as {type: Int32, primary: true}
    name: String,
    gender: {type: String?, default: "male"},
    age: {type: Int32, default: 10},
    description: String?,
    created_at: Time?,
    updated_at: Time | Nil
  )

  has_many :addresses, Address
  has_many :facebook_profiles, FacebookProfile
  has_and_belongs_to_many :countries, Country
  has_and_belongs_to_many :facebook_many_profiles, FacebookProfile, join_foreign: :profile_id
  has_one :main_address, Address, {where { _main }}
  has_one :passport, Passport

  validates_inclusion :age, 13..75
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
    contact_id: Int32?,
    details: JSON::Any?
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

  validates_with EnnValidator
  belongs_to :contact, Contact
end

class Profile < Jennifer::Model::Base
  mapping(
    id: Primary32,
    login: String,
    contact_id: Int32?,
    type: String
  )

  belongs_to :contact, Contact
end

class FacebookProfile < Profile
  mapping(
    uid: String
  )

  has_and_belongs_to_many :facebook_contacts, Contact, foreign: :profile_id
end

class TwitterProfile < Profile
  mapping(
    email: String
  )
end

class Country < Jennifer::Model::Base
  mapping(
    id: Primary32,
    name: String
  )

  validates_exclusion :name, ["asd", "qwe"]
  validates_uniqueness :name

  has_and_belongs_to_many :contacts, Contact
end
```

## Mapping definition

You should define all fields that you'd like to grep from the particular table, other words - define model's mapping.

`.mapping(options, strict = true)` macro stands for defining all model attributes. If field has no extra parameter,
you can just specify name and type (type in case of crystal language): `field_name: :Type`. Named tuple can be used
instead of type. Next keys are supported:

| argument | description |
| --- | --- |
| `:type` | crystal data type |
| `:primary` | mark field as primary key (default is `false`) |
| `:null` | allows field to be `nil` (default is `false` for all fields except primary key |
| `:default` | default value which will be set during creating **new** object |
| `:column` | database column name associated with this attribute (default is attribute name) |
| `:getter` | if getter should be created (default - `true`) |
| `:setter` | if setter should be created (default - `true`) |
| `:virtual` | mark field as virtual - will not be stored and retrieved from db |
| `:converter` | class/module/object that is used to serialize/deserialize field |
| `:auto` | indicate whether primary field is autoincrementable (by default `true` for `Int32` and `Int64`) |

Every `.mapping` call generates type alias `AttrType` which is a union of `Jennifer::DBAny` and any used arbitrary type.

To make some field nillable tou can use any of the next options:

- pass `null: true` option to the named tuple
- use `?` in type declaration (e.g. `some_field: String?` or `some_filed: {type: String?}`)
- use union with `Nil` in the type declaration (e.g. `some_field: String | Nil` or `some_filed: {type: String | Nil}`)

If you don't want to define all the table fields - pass `false` as second argument (this will disable default strict mapping mode).

`.mapping` defines next methods:

| method | args | description |
| --- | --- | --- |
| `.new` | `Hash(String \| Symbol, DB::Any), NamedTuple, MySql::ResultSet` | constructors |
| `.field_count`| | number of fields |
| `.field_names`| | all fields names |
| `._{{field_name}}` | | helper method for building queries |
| `.coerce_{{field_name}}` | `String` | coerces string to `field_name` type |
| `.primary` | | returns criterion for primary field (query DSL) |
| `.primary_field_name` | | name of primary field |
| `.create` | `Hash(String \| Symbol, DB::Any)`, `NamedTuple` | creates object, stores it to db and returns it |
| `.create!` | `Hash(String \| Symbol, DB::Any)`, `NamedTuple` | creates object, stores it to db and returns it; otherwise raise exception |
| `.build` | `Hash(String \| Symbol, DB::Any), NamedTuple` | builds object |
| `.create` | `Hash(String \| Symbol, DB::Any)`, `NamedTuple` | builds object from hash and saves it to db with all callbacks |
| `.create!` | `Hash(String \| Symbol, DB::Any)`, `NamedTuple` | builds object from hash and saves it to db with callbacks or raise exception |
| `#{{field_name}}` | | getter |
| `#{{field_name}}_changed?` | | presents whether field is changed |
| `#{{field_name}}!` | | getter with `not_nil!` if `null: true` was passed |
| `#{{field_name}}=`| | setter |
| `#{{field_name}}_changed?` | | shows if field was changed |
| `#new_record?` | | returns `true` if record has `nil` primary key (is not stored to db) |
| `#changed?` | | shows if any field was changed |
| `#primary` | | value of primary key field |
| `#save` | | saves object to db; returns `true` if success and `false` elsewhere |
| `#save!` | | saves object to db; returns `true` if success or rise exception otherwise |
| `#to_h` | | returns hash with all attributes |
| `#to_str_h` | | same as `#to_h` but with String keys |
| `#attribute` | `String \| Symbol` | returns attribute value by it's name |
| `#changed?` | | check if any field was changed |
| `#set_attribute` | `String \| Symbol`, `DB::Any` | sets attribute by given name |
| `#attribute` | `String \| Symbol` | returns attribute value by it's name |

Also `#{{field_name}}?` predicate method for the case when it is boolean.

All allowed types are listed on the [Migration](https://imdrasil.github.io/jennifer.cr/docs/migration) page.

All defined mapping properties are accessible via `COLUMNS_METADATA` constant and `::columns_tuple` method.

It may be useful to have one parent class for all your models - just make it abstract and everything will work well:

```crystal
abstract class ApplicationRecord < Jennifer::Model::Base
end

class SomeModel < ApplicationRecord
  mapping(
    id: Int32,
    name: String
  )
end
```

### Important restrictions:

- models currently must have a `primary` field.
- if your model also uses `JSON.mapping`, `JSON::Serializable`, or other kinds of mapping macros, you must be careful
  to use Jennifer's `mapping` macro last in order for all model features to work correctly.

```crystal
class User < Jennifer::Model::Base
  # JSON.mapping used *before* model mapping:
  JSON.mapping(id: Int32, name: String)

  # Model mapping used last:
  mapping(id: Primary32, name: String)
end
```

### Converters

To define a field converter create a class/module which implements next static methods:

- `.from_db(DB::ResultSet, NamedTuple)` - converts field reading it from db result set;
- `.to_db(T, NamedTuple)` - converts field to the db format;
- `.from_hash(Hash(String, Jennifer::DBAny | T), String, NamedTuple)` - converts field (which name is the 2nd argument) from the given hash (this method is called only if hash has required key).

There are 7 predefined converters:

- `Jennifer::Model::JSONConverter` - default converter for `JSON::Any` (it is applied automatically for `JSON::Any` fields) - takes care of JSON-string-JSON conversion;
- `Jennifer::Model::TimeZoneConverter` - default converter for `Time` - converts from UTC time to local time zone;
- `Jennifer::Model::EnumConverter` - converts string values to crystal `enum`;
-`Jennifer::Model::BigDecimalConverter` - converts numeric database type to `BigDecimal` value which allows to perform operations with specific scale;
- `Jennifer::Model::JSONSerializableConverter(T)` - converts JSON to `T` (which includes `JSON::Serializable);
- `Jennifer::Model::NumericToFloat64Converter` - converts `PG::Numeric` to `Float64` (Postgres only);
- `Jennifer::Model::PgEnumConverter` - converts `ENUM` value to `String` (Postgres only).

### Arbitrary type

Model field can be of any type it is required to. But to achieve this you should specify corresponding converter to serialize/deserialize value to/from database format. One of the most popular examples is "embedded document" - JSON field that has known mapping and is mapped to crystal class.

```crystal
class Location
  include JSON::Serializable

  property latitude : Float64
  property longitude : Float64
end

class Address < Jennifer::Model::Base
  mapping(
    # ...
    details: { type: Location?, converter: Jennifer::Model::JSONSerializableConverter(Location) }
  )
end
```

Now instances of `Location` class can be used in all constructors/setters/update methods. The only exception is query methods - they support only `Jennifer::DBAny` values.

Other popular example is crystal `enum` usage.

```crystal
enum Category
  GOOD
  BAD
end

class Note < Jennifer::Model::Base
  mapping(
    category: { type: Category?, converter: Jennifer::Model::EnumConverter(Category) }
  )
end
```

### Mapping Types

Jennifer has built-in system of predefined options for some usage. They are not data types on language level (you can't defined variable of `Primary32` type) and can be used only in mapping definition (standard usage).

```crystal
class Post < Jennifer::Model::Base
  mapping(
    id: Primary32,
    # or even with full definition
    pk: { type: Primary32, primary: false, virtual: true }
  )
end
```

All overrides from full definition will be respected and used instead of predefined for such a type.

To defined your own type define it such a way it may be lexically accessible from place you want to use it:

```crystal
class ApplicationRecord < Jennifer::Model::Base
  EmptyString = {
    type: String,
    default: ""
  }

  {% TYPES << "EmptyString" %}
  # or if this is outside of model or view scope
  {% ::Jennifer::Macros::TYPES << "EmptyString" %}
end
```

> Obviously, registered type added to the `TYPES` should be the same as defined constant; also it should be stringified.

Existing mapping types:

- `Primary32 = { type: Int32, primary: true }`
- `Primary64 = { type: Int64, primary: true }`
- `Password = { type: String?, virtual: true, setter: false }`

### Virtual attributes

If you pass `virtual: true` option for some field - it will not be stored to db and tried to be retrieved from there. Such behavior is useful if you have model-level attributes but it is not obvious to store them into db. Such approach allows mass assignment and dynamic get/set based on their name.

```crystal
class User < Jennifer::Model::Base
  mapping(
    id: Primary32,
    password_hash: String,
    password: { type: String?, virtual: true },
    password_confirmation: { type: String?, virtual: true }
  )

  validate_confirmation :password

  before_create :crypt_password

  def crypt_password
    self.password_hash = SomeCryptAlgorithm.call(self.password)
  end
end

User.create!(password: "qwe", password_confirmation: "qwe")
```

## Table name

By default model determines related table name by underscoring and pluralizing own class name. In the case when model is define under some namespace, it's underscored name is considered as table name prefix.

```crystal
User.table_name # "users"
API::Admin::User.table_name # "api_admin_users"
```

To override table name prefix define own `.table_prefix`

```crystal
module Admin
  class Base < Jennifer::Model::Base
    def self.table_prefix
      "private_"
    end
  end

  class User < Base
    mapping(id: Primary32)
  end
end

Admin::User.table_name # "private_users"
```

> As you see `.table_prefix` should return `"_"` at the end to keep naming across application consistent.

> Also to prevent adding table prefix at all - return `nil`.

To override table name just call `.table_name`:

```crystal
class User < Jennifer::Model::Base
  table_name :posts
  # ...
end

class Admin::User < Jennifer::Model::Base
  table_name "users"
end

User.table_name # "posts"
Admin::User.table_name # "users"
```

> `.table_name` accepts table name that already includes prefix.

## Converting form Web options

In the Web world all data got submitted forms will be recognized as `Hash(String, String)` which is not acceptable by your models. To resolve this use [form_object](https://github.com/imdrasil/form_object) shard.
