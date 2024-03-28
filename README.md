# Jennifer [![Latest Release](https://img.shields.io/github/release/imdrasil/jennifer.cr.svg)](https://github.com/imdrasil/jennifer.cr/releases) [![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://imdrasil.github.io/jennifer.cr/docs/)

ActiveRecord pattern implementation for Crystal with a powerful query DSL, validation, relationship definition, translation and migration mechanism.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  jennifer:
    github: imdrasil/jennifer.cr
    version: "~> 0.13.0"
```

### Requirements

- you need to choose one of the existing drivers for your DB: [mysql](https://github.com/crystal-lang/crystal-mysql) or [postgres](https://github.com/will/crystal-pg); sqlite3 adapter automatically installs required driver for it;
- crystal `>= 1.0.0`.

> MySQL `8.0.36` and above isn't supported at the moment

## Usage

Jennifer allows you to maintain everything for your models - from DB migrations and field mapping to callbacks and building queries. For detailed information see the [docs](https://imdrasil.github.io/jennifer.cr/docs/) and [API documentation](https://imdrasil.github.io/jennifer.cr/versions).

### CLI

For command management Jennifer uses [Sam](https://github.com/imdrasil/sam.cr). Due to this you can easily create/migrate/drop database or invoke generator to bootstrap your models and migrations.

### Migration

Jennifer has built-in database migration management system. Migrations allow you to organize all database changes.

To start using Jennifer you'll first need to generate a migration:

```shell
$ crystal sam.cr generate:migration CreateContact
```

then fill the created migration file with content:

```crystal
class CreateContact < Jennifer::Migration::Base
  def up
    # Postgres requires to create specific enum type
    create_enum(:gender_enum, ["male", "female"])
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
$ crystal sam.cr db:setup
```

to create the database and run the newly created migration.

### Model

Jennifer provides next features:

- flexible model schema definition
- relationship definition (`belongs_to`, `has_many`, `has_one`, `has_and_belongs_to_many`) - including polymorphic ones
- built-in extendable validations
- model-specific query scope definition
- callbacks
- database view support
- SQL translations

Hers is a model example:

```crystal
class Contact < Jennifer::Model::Base
  with_timestamps
  mapping(
    id: Primary64, # is an alias for Int64? primary key
    name: String,
    gender: { type: String?, default: "male" },
    age: { type: Int32, default: 10 },
    description: String?,
    created_at: Time?,
    updated_at: Time?
  )

  has_many :facebook_profiles, FacebookProfile
  has_and_belongs_to_many :countries, Country
  has_and_belongs_to_many :facebook_many_profiles, FacebookProfile, join_foreign: :profile_id
  has_one :passport, Passport

  validates_inclusion :age, 13..75
  validates_length :name, minimum: 1, maximum: 15
  validates_with_method :name_check

  scope :older { |age| where { _age >= age } }
  scope :ordered { order(name: :asc) }

  def name_check
    return unless description && description.not_nil!.size > 10
    errors.add(:description, "Too large description")
  end
end
```

### Query DSL

Jennifer allows you to query the DB using a flexible DSL:

```crystal
Contact
  .all
  .left_join(Passport) { _contact_id == _contact__id }
  .order(id: :asc).order(Contact._name.asc.nulls_last)
  .with_relation(:passport)
  .to_a
Contact.all.eager_load(:countries).where { __countries { _name.like("%tan%") } }
Contact.all.group(:gender).group_avg(:age, PG::Numeric)
```

Supported features:

- fetching model objects from the database
- fetching records from a specific table
- *magic* underscore  table column notation which allows effectively reference any table column or alias
- eager loading of model associations any levels deep
- support of common SQL functions (including aggregations) and mechanism to register own ones
- flexible DSL of all SQL clauses (`SELECT`, `FROM`, `WHERE`, `JOIN`, `GROUP BY`, etc.)
- `CTE` support
- `JSON` operators
- table and column aliasing

Much more about the query DSL can be found in the wiki [page](./docs/query_dsl.md).

### Internationalization

You can easily configure error message generated for certain validation violation for a specific model or globally. Model and attribute names can be easily configured as well. For internationalization purpose [i18n](https://github.com/TechMagister/i18n.cr) is used. For more details how does it work see [wiki](./docs/internationalization_dsl.md).

### Logging & Debugging

Jennifer uses a [standard](https://crystal-lang.org/api/latest/Log.html) Crystal logging mechanism so you could specify your own logger, backend and formatter:

```crystal
Log.setup "db", :debug, Log::IOBackend.new(formatter: Jennifer::Adapter::DBFormatter)
```

`Jennifer::Model::Base#inspect` returns formatted information about model attributes filtering out all unnecessary information.

```crystal
Address.first!.inspect
# #<Address:0x7efde96ac0d0 id: 1, street: "Ant st. 69", contact_id: nil, created_at: 2019-06-10 11:11:11.665032000 +03:00 Local>
```

Also, you can get a query execution plan explanation right from your code - just execute `#explain` on query to get appropriate information (output is database specific):

```crystal
Contact.all.explain # => Seq Scan on contacts  (cost=0.00..14.30 rows=100.0 width=320)
```

### Testing tips

The fastest way to rollback all changes in the DB after test case is by using a transaction. So add:

```crystal
Spec.before_each do
  Jennifer::Adapter.default_adapter.begin_transaction
end

Spec.after_each do
  Jennifer::Adapter.default_adapter.rollback_transaction
end
```

to your `spec_helper.cr`. NB. you could simply use regular deleting or truncation, but a transaction will provide a 15x speed up (at least for postgres; mysql gets less impact).

> These functions can be safely used only under test environment.

## Versioning

Now that Jennifer is under heavy development, there could be many breaking changes. So please check the release notes to check if any of the changes may prevent you from using it. Also, until this library reaches a beta version, the next version rules will be followed:

- all bug fixes, new minor features or (sometimes) ones that don't break the existing API will be added as a patch number (e.g. 0.3.**4**);

- all breaking changes and new important features (as well as reaching a milestone) will be added by bumping the minor digit (0.**4**.0);

So even a patch version change could bring a lot of new stuff.

If there is a branch for the next release - it will be removed 1 month after the release. So please use them only as a hotfix or for experiments or contribution.

## Development

> Before developing any feature please create an issue where you describe your idea.

To setup dev environment run `./scripts/setup.sh` - it creates `./scripts/database.yml` configuration file. You can override there any values specific to your environment (like DB user & password).

To create the databases:

```shell
# Postgres
$ make sam db:setup

# Mysql
$ DB=mysql make sam db:setup
```

### Running tests

All unit tests are written using core `spec`. Also in `spec/spec_helper.cr` some custom unit test matchers are defined. All migrations are under the `./scripts/migrations` directory.

The common way to run tests is just use using regular crystal spec tool:

```shell
$ crystal spec
```

By default `postgres` adapter is used. To run tests against `mysql` add `DB=mysql` before command. Also custom database user and password could be specified:

In case you need to set the database user or password, use:

```shell
$ DB_USER=user DB_PASSWORD=pass crystal spec
```

To see query logs set `STD_LOGS=1`.

#### Testing multiadapter support

To run tests with multiple adapter involved you should create and migrate database with `PAIR=1` environment variable defined. For testing purpose `mysql` adapter will be created when `postgres` one is used as a main one and vice verse. Therefore both databases should be available to receive connections.

Also `PAIR` variable should be defined when running tests.

#### Integration tests

Except unit tests there are also several *integration* tests. These tests checks opportunity to compile and invoke Jennifer functionality in some special edge cases (e.g. without defined models, migrations, etc.).

To run integration test just use standard spec runner:

```shell
$ crystal spec spec/integration/<test_name>.cr
```

Each test file is required to be invoked separately as it may have own configuration.

### Documentation generation

Self documentation is not fully support yet but docs can be compiled using this shell script:

```shell
$ ./generate-docs.sh
```

NB. It also depends on then chosen adapter (postgres by default).

## Contributing

1. [Fork it]( https://github.com/imdrasil/jennifer.cr/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

Please ask me before starting work on smth. Also often there is a separate branch for the future minor release that includes all breaking changes.

## Contributors

- [imdrasil](https://github.com/imdrasil) Roman Kalnytskyi - creator, maintainer
