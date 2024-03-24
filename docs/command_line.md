# Command Line

For command management Jennifer uses [Sam](https://github.com/imdrasil/sam.cr). So in your `sam.cr` just add loading migrations and Jennifer hooks.

```crystal
require "./your_configuration_folder/*" # with requiring jennifer and her adapter
require "./migrations/*"
require "sam"
load_dependencies "jennifer"

# your custom tasks here
```

## DB namespace

### db:create

Creates database described in the configuration.

```shell
$ crystal sam.cr db:create
```

> Will create only **one** database. This means that for test environment (and for any extra environment you want) this command should be invoked separately. This is common for all commands in this section.

If database is already exists - successfully finishes (returns code 0).

### db:drop

Drops database described in the configuration.

```shell
$ crystal sam.cr db:drop
```

### db:setup

Creates database, invokes all pending migrations and populate database with seeds.

```shell
$ crystal sam.cr db:setup
```

### db:migrate

Runs all pending migrations and stores them in the `versions` table. After execution of new migrations database schema is dumped to the `structure.sql` file.

```shell
$ crystal sam.cr db:migrate
```

### db:step

Runs exact count of migrations (1 by default).

```shell
$ crystal sam.cr db:step
$ crystal sam.cr db:step <count>
```

### db:rollback

Rollbacks the last run migration

```shell
$ crystal sam.cr db:rollback
```

To rollbacks specific count of migrations:

```shell
$ crystal sam.cr db:rollback <count>
```

To rollback to the specific version:

```shell
$ crystal sam.cr db:rollback -v <migration_version>
```

### db:version

Outputs current database version.

```shell
$ crystal sam.cr db:version
```

### db:seed

Populates database with seeds. By default this task is empty and should be defined per project
bases.

```shell
$ crystal sam.cr db:seed
```

### db:schema:load

Creates database from the `structure.sql` file.

```shell
$ crystal sam.cr db:schema:load
```

> Running migration after this may cause error messages because of missing any information about run migrations in scope of current schema generating.

## Generating namespace

### generate:model

Generates model and related migration based on the given definition.

```shell
$ crystal sam.cr generate:model <ModelName> [field1:type] ... [fieldN:type?]
```

Example:

```shell
$ crystal sam.cr generate:model Article title:string text:text? author:reference
```

```crystal
# ./src/models/article.cr

class Article < Jennifer::Model::Base
  with_timestamps

  mapping(
    id: Primary64,
    title: String,
    text: String?,
    author_id: Int64?,
    created_at: Time?,
    updated_at: Time?,
  )

  belongs_to :author, Author
end

# ./db/migrations/<timestamp>_create_articles.cr

class CreateArticles < Jennifer::Migration::Base
  def up
    create_table :articles do |t|
      t.string :title, {:null => false}
      t.text :text

      t.reference :author

      t.timestamps
    end
  end

  def down
    drop_table :articles if table_exists? :articles
  end
end
```

Available types:

* `bool`
* `bigint`
* `integer`
* `short`
* `tinyint`
* `float`
* `double`
* `string`
* `text`
* `timestamp`
* `date_time`
* `json`
* `reference`

The `?` symbol at the end of type name means that this field is nilable.

### generate:migration

Generates simple migration template.

```shell
$ crystal sam.cr generate:migration CreateArticles
```
