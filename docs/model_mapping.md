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

`%mapping(options, strict = true)` macros stands for defining all model attributes. If field has no extra parameter, you can just specify name and type (type in case of crystal language): `field_name: :Type`. Named tuple can be used instead of type. Next keys are supported:

| argument | description |
| --- | --- |
| `:type` | crystal data type |
| `:primary` | mark field as primary key (default is `false`) |
| `:null` | allows field to be `nil` (default is `false` for all fields except primary key |
| `:default` | default value which will be set during creating **new** object |
| `:getter` | if getter should be created (default - `true`) |
| `:setter` | if setter should be created (default - `true`) |
| `:virtual` | mark field as virtual - will not be stored and retrieved from db |
| `:converter` | class be used to serialize/deserialize value |

To define field converter create a class which implements next methods:

- `.from_db(DB::ResultSet, Bool)` - converts field reading it from db result set (second argument describes if field is nillable);
- `.to_db(SomeType)` - converts field to the db format;
- `.from_hash(Hash(String, Jennifer::DBAny), String)` - converts field from the given hash (second argument is a field name).

There are 2 predefined converters:

- `Jennifer::Model::JSONConverter` - default converter for `JSON::Any`;
- `Jennifer::Model::NumericToFloat64Converter` - converts Postgres `PG::Numeric` to `Float64`.

To make some field nillable tou can use any of the next options:

- pass `null: true` option to the named tuple
- use `?` in type declaration (e.g. `some_field: String?` or `some_filed: {type: String?}`)
- use union with `Nil` in the type declaration (e.g. `some_field: String | Nil` or `some_filed: {type: String | Nil}`)

If you don't want to define all the table fields - pass `false` as second argument (this will disable default strict mapping mode).

`%mapping` defines next methods:

| method | args | description |
| --- | --- | --- |
| `#initialize` | `Hash(String \| Symbol, DB::Any), NamedTuple, MySql::ResultSet` | constructors |
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
| `::build_params` | `Hash(String, String?)` | converts given string-based hash using field mapping |
| `#save` | | saves object to db; returns `true` if success and `false` elsewhere |
| `#save!` | | saves object to db; returns `true` if success or rise exception otherwise |
| `#to_h` | | returns hash with all attributes |
| `#to_str_h` | | same as `#to_h` but with String keys |
| `#attribute` | `String \| Symbol` | returns attribute value by it's name |
| `#changed?` | | check if any field was changed |
| `#set_attribute` | `String \| Symbol`, `DB::Any` | sets attribute by given name |
| `#attribute` | `String \| Symbol` | returns attribute value by it's name |

All allowed types are listed on the [Migration](https://imdrasil.github.io/jennifer.cr/docs/migration) page.

All defined mapping properties are accessible via `COLUMNS_METADATA` constant and `::columns_tuple` method.

**Important restriction** - model with no primary field is not allowed for now.

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

### Numeric fields

Crystal type of a numeric (decimal) field depends on chosen adapter: `Float64` for mysql and `PG::Numeric` for Postgres. Sometimes usage of `PG::Numeric` with Postgres may be annoying. To convert it to another type at the object building stage you can pass `numeric_converter` option with method to be used to convert `PG::Numeric` to the defined field `type`.

```crystal
class Product < Jennifer::Model::Base
  mapping(
    id: Primary32,
    #...
    price: { type: Float64, numeric_converter: :to_f64 }
  )
end
```

## Table name

Automatically model is associated with table with underscored pluralized name of it's class, but custom one can be specified defining `::table_name`. This means no modules will affect name generating.

```crystal
Admin::User.table_name # "users"
```

To provide special table prefix per module basis use super class with defined `::table_prefix` method:

```crystal
module Admin
  class Base < Jennifer::Model::Base
    def self.table_prefix
      "admin_"
    end
  end

  class User < Base
    mapping(id: Primary32)
  end
end

Admin::User.table_name # "admin_users"
```

## Virtual attributes

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

## Converting form options

In the Web world all data got submitted forms will be recognized as `Hash(String, String)` which is not acceptable by your models. To resolve this case `.build_params` may be used - just pass received string based hash and all fields will be converted respectively to the class mapping.

```crystal
class Post < Jennifer::Model::Base
  mapping(
    id: Primary32,
    name: String,
    age: Int32
  )
end

opts = { "name" => "Jason", "age" => "23" }

Post.build_params(opts) # { "name" => "Jason", "age" => 23 } of String => Jennifer::DBAny
```
