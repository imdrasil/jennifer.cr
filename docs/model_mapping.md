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

  validates_with [EnnValidator]
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
    id: Primary32,
    name: String
  )

  validates_exclusion :name, ["asd", "qwe"]
  validates_uniqueness :name

  has_and_belongs_to_many :contacts, Contact
end
```

`%mapping(options, strict = true)` macros stands for describing all model attributes. If field has no extra parameter, you can just specify name and type (type in case of crystal language): `field_name: :Type`. But you can use tuple and provide next parameters:

| argument | description |
| --- | --- |
| `:type` | crystal data type (don't use question mark - for now you can use only `:null` option) |
| `:primary` | mark field as primary key (default is `false`) |
| `:null` | allows field to be `nil` (default is `false` for all fields except primary key |
| `:default` | default value which be set during creating **new** object |
| `:getter` | if getter should be created (default - `true`) |
| `:setter` | if setter should be created (default - `true`) |

To make some field nillable tou can use any of next options:

- pass `null: true` option to the named tuple
- use `?` in type declaration (e.g. `some_field: String?` and `some_filed: {type: String?}`)
- use union with `Nil` in the type declaration (e.g. `some_field: String | Nil` and `some_filed: {type: String | Nil}`)

Also for there is a shortcut for defining `Int32` and `Int64` primary keys

If you don't want to define all the table fields - pass `false` as second argument.

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
| `#save` | | saves object to db; returns `true` if success and `false` elsewhere |
| `#save!` | | saves object to db; returns `true` if success or rise exception otherwise |
| `#to_h` | | returns hash with all attributes |
| `#to_str_h` | | same as `#to_h` but with String keys |
| `#attribute` | `String \| Symbol` | returns attribute value by it's name |
| `#attributes_hash` | | returns `to_h` with deleted `nil` entries |
| `#changed?` | | check if any field was changed |
| `#set_attribute` | `String \| Symbol`, `DB::Any` | sets attribute by given name |
| `#attribute` | `String \| Symbol` | returns attribute value by it's name |

All allowed types are listed on the [Migration](https://imdrasil.github.io/jennifer.cr/docs/migration) page.


Automatically model is associated with table with underscored pluralized name of it's class, but special name can be defined using `::table_name` method in own body before using any relation (`::singular_table_name` - for singular variant).

All defined mapping properties are accessible via `COLUMNS_METADA` constant and `::columns_tuple` method.

**Important restriction** - model with no primary field is not allowed for now.

It may be usefull to have one parent class for your model - just make it abstract and everything will work well:

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