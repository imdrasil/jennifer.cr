# Jennifer [![Build Status](https://travis-ci.org/imdrasil/jennifer.cr.svg)](https://travis-ci.org/imdrasil/jennifer.cr) [![Latest Release](https://img.shields.io/github/release/imdrasil/jennifer.cr.svg)](https://github.com/imdrasil/jennifer.cr/releases) [![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://imdrasil.github.io/jennifer.cr/docs/)

ActiveRecord pattern implementation for Crystal with a powerful query DSL, validation, relationship definition, translation and migration mechanism.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  jennifer:
    github: imdrasil/jennifer.cr
    version: "~> 0.6.1"
```

### Requirements

- you need to choose one of existing adapters for your db: [mysql](https://github.com/crystal-lang/crystal-mysql) or [postgres](https://github.com/will/crystal-pg);
- crystal `>= 0.26.1`

## Usage

Jennifer allows you to maintain everything for your models - from db migrations and field mapping to callbacks and building queries. For detailed information see the [guide](https://imdrasil.github.io/jennifer.cr/docs/) and [API documentation](https://imdrasil.github.io/jennifer.cr/versions).

### Migration

To start using Jennifer you'll first need to generate a migration:

```shell
$ crystal sam.cr -- generate:migration CreateContact
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
$ crystal sam.cr -- db:setup
```

to create the database and run the newly created migration.
> For command management Jennifer uses [Sam](https://github.com/imdrasil/sam.cr).

### Model

Jennifer provides next features:

- flexible model schema definition
- relationship definition (`belongs_to`, `has_many`, `has_one`, `has_and_belongs_to_many`)
- validation
- model-specific query scope definition
- callbacks
- view support
- translations

Hers is model example:

```crystal
class Contact < Jennifer::Model::Base
  with_timestamps
  mapping(
    id: Primary32, # is an alias for Int32? primary key
    name: String,
    gender: {type: String?, default: "male"},
    age: {type: Int32, default: 10},
    descriptionsString?,
    created_at:sime?,
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

More details you can find in the documentation.

### Query DSL

Jennifer allows you to query the db using a flexible DSL:

```crystal
Contact.all.left_join(Passport) { _contact_id == _contact__id }
            .order(id: :asc)
            .with(:passport).to_a
Contact.all.eager_load(:countries).where { __countries { _name.like("%tan%") } }
Contact.all.group(:gender).group_avg(:age, PG::Numeric)
```

Much more about the query DSL can be found on the wiki [page](./docs/query_dsl.md).

### SQLite Support

SQLite3 has many limitations so adding its support isn't a very easy task, but it is still important to Jennifer.

### Versioning

Now that Jennifer is under heavy development, there could be many breaking changes. So please check the release notes to check if any of the changes may prevent you from using it. Also, until this library reaches a beta version, the next version rules will be followed:

- all bugfixes, new minor features or (sometimes) ones that don't break the existing API will be added as a patch number (e.g. 0.3.**4**);

- all breaking changes and new important features (as well as reaching a milestone) will be added by bumping the minor digit (0.**4**.0);

So even a patch version change could bring a lot of new stuff.

If there is a branch for the next release - it will be removed 1 month after the release. So please use them only as a hotfix or for experiments or contribution.

### Test tips

The fastest way to rollback all changes in the DB after test case is by using a transaction. So add:

```crystal
Spec.before_each do
  Jennifer::Adapter.adapter.begin_transaction
end

Spec.after_each do
  Jennifer::Adapter.adapter.rollback_transaction
end
```

to your `spec_helper.cr`. NB. you could simply use regular deleting or truncation, but a transaction will provide a 15x speed up (at least for postgres; mysql gets less impact).

> This functions can be safely used only under test environment.

## Development

> Before developing any feature please create an issue where you describe your idea.

Before development create the db user (see `/spec/config.cr` file) and database:

```shell
# Postgres
$ crystal examples/run.cr -- db:setup

# Mysql
$ DB=mysql crystal examples/run.cr -- db:setup
```

### Running tests

All unit tests are written using core `spec` component. Also in `spec/spec_helper.cr` some custom unit test matchers are defined. All migrations are under the `./examples/migrations` directory.

The common way to run tests is just use using regular crystal spec tool:

```shell
$ crystal spec
```

PostgreSQL is used by default, but MySql is also supported while running tests by specifying environment variable `DB=mysql`:

In case you need to set the database user or password, use:

```shell
$ DB_USER=user DB_PASSWORD=pass crystal spec
```

#### Integration tests

Except unit tests there are also several *integration* tests. These tests checks possibility to compile and invoke jennifer functionality in some special edge cases (e.g. without defined models, migrations, etc.).

To run integration test just use standard spec runner:

```shell
$ crystal spec spec/integration/<test_name>.cr
```

Each test file is required to be invoked separatelly as it may have own configuration.

To run docker-related tests (by the way, all of them run only with mysql) firstly you should run docker container and specify environment variable `DOCKER=1`. For more details take a look at `spec/integration/sam/*` application files and `examples/run_docker_mysql.sh` docker boot script.

## Documentation

Self documentation is not fully support yet but docs can be compiled using this shell script:

```shell
$ ./generate-docs.sh
```

NB. It also depends on then chosen adapter (postgres by default).

## Similar shards

- [active_record.cr](https://github.com/waterlink/active_record.cr) - small simple AR realization
- [crecto](https://github.com/vladfaust/core.cr) - based on Phoenix's Ecto lib and follows the repository pattern
- [granite-orm](https://github.com/amberframework/granite-orm) - light weight orm focusing on mapping fields from request to your objects
- [topaz](https://github.com/topaz-crystal/topaz) - inspired by AR ORM with migration mechanism
- [micrate](https://github.com/juanedi/micrate) - standalone database migration tool for crystal

## Contributing

1. [Fork it]( https://github.com/imdrasil/jennifer.cr/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

Please ask me before starting work on smth.

## Contributors

- [imdrasil](https://github.com/imdrasil) Roman Kalnytskyi - creator, maintainer
