# Getting started

## Installation

Add the shard to your `shards.yml`. Also

```yml
dependencies:
  jennifer:
    github: imdrasil/jennifer.cr
    version: "~> 0.8.3"
```

For MySQL and PostgreSQL you need to add related driver shard - [crystal-mysql](https://github.com/crystal-lang/crystal-mysql) or [crystal-pg](https://github.com/will/crystal-pg):

```yml
dependencies:
  jennifer:
    github: imdrasil/jennifer.cr
    version: "~> 0.8.3"
  pg:
    github: will/crystal-pg
  # or for mysql
  crystal-mysql:
    github: crystal-lang/crystal-mysql
```

If you want to use SQLite3 - add [Jennifer SQLite3 adapter](https://github.com/imdrasil/jennifer_sqlite3_adapter):

```yml
dependencies:
  jennifer:
    github: imdrasil/jennifer.cr
    version: "~> 0.8.2"
  jennifer_sqlite3_adapter:
    github: imdrasil/jennifer_sqlite3_adapter
```

It is shipped with SQLite driver so you don't need add it explicitly.

In this tutorial we will be using PostgreSQL adapter.

### Setting up database connection

Create `./config` folder - it will contain all your configurations. Also create `./config/initializers/database.cr` with following content:

```crystal
require "jennifer"
require "jennifer/adapter/postgres"
# require "jennifer/adapter/mysql" for mysql

Jennifer::Config.read("config/database.yml", ENV["APP_ENV"]? || "development")
jennifer::Config.from_uri(ENV["DATABASE_URI"]) if ENV.has_key?("DATABASE_URI")

Jennifer::Config.configure do |conf|
  conf.logger.level = Logger::DEBUG
end
```

This allows you to put all database related configuration to structured yml file and override it with custom database connection URI passing it in `DATABASE_URI`.

Now let's create `./config/database.yml`:

```crystal
default: &default
  host: localhost
  user: user_name
  password: user_password
  adapter: postgres

development:
  <<: *default
  db: application_database_name_development

test:
  <<: *default
  db: application_database_name_development

production:
  <<: *default
  db: application_database_name_development
```

> NOTE: prefer creating shared database configuration file template rather than exact one (aka `database.example.yml`) so everyone can configure it for themselves.

Now create `./config/config.cr` which is responsible for loading all dependency's configurations:

```crystal
require "./initializers/**"

# This is optional; it depends how you would like to load your models - centralized or by demand.
require "../src/models/*"
```

### Translations

Jennifer under the hood use [i18n](https://github.com/TechMagister/i18n.cr) for error message translation. Create `./config/locales/en.yml` for any custom translations and add `./config/initializers/zzz_i18n.cr` with following content:

```crystal
I18n.load_path += ["./config/locales"]

I18n.init
```

### CLI

Now to be able to use [sam](https://github.com/imdrasil/sam.cr) task manager create file `sam.cr` in you application root folder with following content:

```crystal
require "./your_configuration_folder/*" # with requiring jennifer and her adapter
require "./migrations/*"
require "sam"
load_dependencies "jennifer"

# your custom tasks here

Sam.help
```

Now you can invoke `$ crystal sam.cr -- help` to get list of all available tasks. Also you can generate makefile shorthand for this - just invoke `$ crystal sam.cr -- generate:makefile`. Now you are able to invoke Sam tasks by `make` - `$make sam help`.

## Usage

### First Models

We will use built-in generator to obtain our first model. Just create a folder `./src/models` for your models and invoke

```
$ make sam generate:model User name:string age:integer
```

This generates 2 files:

* `./src/models/user.cr` - files containing model definition

  ```crystal
  class User < Jennifer::Model::Base
    with_timestamps

    mapping(
      id: Primary32,
      name: String,
      age: Int32,
    )
  end
  ```
* `./db/migrations/<timestamp>_create_users.cr` - migration file (it is required to change your database schema)

  ```crystal
  class CreateUsers < Jennifer::Migration::Base
    def up
      create_table :users do |t|
        t.string :title, { :null => false }
        t.integer :age, { :null => false }

        t.timestamps
      end
    end

    def down
      drop_table :users if table_exists? :users
    end
  end
  ```

To be able to use our new model we need to populate schema changes to the database. For this invoke next commands:

* `$ make sam db:create` - this creates a new database (should be invoked only once at setup stage);
* `$ make sam db:migrate` - invokes all pending migrations.

Now we are able to use our model:

```crystal
user = User.create({ name: "New User", age: 100 })
puts user.inspect
```
