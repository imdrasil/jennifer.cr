# Jennifer [![Build Status](https://travis-ci.org/imdrasil/jennifer.cr.svg)](https://travis-ci.org/imdrasil/jennifer.cr) [![Latest Release](https://img.shields.io/github/release/imdrasil/jennifer.cr.svg)](https://github.com/imdrasil/jennifer.cr/releases)

Another ActiveRecord pattern implementation for Crystal with great query DSL and migration mechanism.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  jennifer:
    github: imdrasil/jennifer.cr
```

**Also** you need to choose one of existing adapters for your db: [mysql](https://github.com/crystal-lang/crystal-mysql) or [postgres](https://github.com/will/crystal-pg).

## Usage

Jennifer allows you to maintain everything for your models - from db migrations and field mapping to callbacks and building queries. For detailed information see the [documentation](./docs/index.md).

#### Migration

To start using Jennifer firstly generate migration:

```shell
$ crystal sam.cr -- generate:migration CreateContact
```

and fill created migration file with next content:

```crystal
class CreateContact20170119011451314 < Jennifer::Migration::Base
  def up
    create_enum(:gender_enum, ["male", "female"]) # postgres specific command
    create_table(:contacts) do |t|
      t.string :name, {:size => 30}
      t.integer :age
      t.integer :tags, {:array => true}
      t.field :gender, :gender_enum
      t.timestamps
    end
  end

  def down
    drop_table :contacts
    drop_enum(:gender_enum)
  end
end
```

and run

```shell
$ crystal sam.cr -- db:setup
```

to create database and run newly added migration.
> For command management Jennifer uses [Sam](https://github.com/imdrasil/sam.cr).

#### Model

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

  has_many :facebook_profiles, FacebookProfile
  has_and_belongs_to_many :countries, Country
  has_and_belongs_to_many :facebook_many_profiles, FacebookProfile, join_foreign: :profile_id
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

#### Quering

Jennifer allows you to query db using flexible dsl:
```crystal
Contact.all.left_join(Passport) { _contact_id == _contact__id }
            .order("contacts.id": :asc)
            .with(:passport).to_a
Contact.all.includes(:countries).where { __countries { _name.like("%tan%") } }
Contact.all.group(:gender).group_avg(:age, PG::Numeric)
```

Much more about query dsl could be found on wiki [[page|Query-DSL]]

### Important restrictions

- sqlite3 has a lot of limitations so it's support will be added not soon

### Versioning

Now Jennifer is under hard development which could bring a lot of bracking changes. Thats why during Jennifer usage please check release notes (will be added to each release starting from 0.3.4) to check if there is any staff which can stop you from using it. Also until this library will be in beta version next version rules will be followed:

- all bugfixies, new minor features or (sometimes) ones without braking existing API will be added under patch number (e.g. 0.3.*4*);

- all braking changes, new important features will be added under minor digit (0.*4*.0); also reaching milstone will also invoke bumping minor digit.

So even patch version change could bring a lot of new staff.

If there is branch for next release - it will be removed after 1 month after release and after that will be removed. So please use them only as hotfix or for experiments or contibution.

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
- [ ] add possibility for `#group` accept any sql string
- [ ] add polymorphic associations
- [ ] add through to relations
- [ ] add subquery support
- [ ] refactor many-to-many relation
- [ ] add seeds
- [ ] rewrite tests to use minitest
- [ ] add self documentation
- [ ] add views support (materialized as well)

Major amount ongoing features and new thoughts are created as issues.

Before development create db user (information is in /spec/config.cr file), run
```shell
$ crystal example/migrate.cr -- db:setup
```

Support both MySql and PostgreSQL are critical. By default postgres are turned on. To run tests with mysql use next:
```shell
$ DB=mysql crystal spec
```

## Documentation

Self documentation is not fully support yet but you can compile docs using shell script:

```shell
$ ./generate-docs.sh
```

It also depends on choosed adapter (postgres is by default).


Now wiki pages have a lot of usefull information. But from 0.3.4 version no information will be added there untill it will be moved to separate `.md` pages to allow contributing.


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
