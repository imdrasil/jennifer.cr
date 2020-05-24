# Multiple adapters

If you have multiple data sources (databases) it is possible to connect to all of them. For this just create a separate `Jennifer::Config` instance apart of the main one and initialize new adapter:

```crystal
separate_config = Jennifer::Config.new.tap do |config|
  config.db = "db_2"
  config.host = "<some host>"
  # ...
  # db.adapter = "mysql" - it is not required to set up any adapter name as we
  # gonna initialize it by our own
end

SEPARATE_ADAPTER = Jennifer::Mysql::Adapter.new(separate_config)
```

Now created above adapter can be used to connect to specified database. It should be used at least in two places: for model connection and for migration one.

## Model

To override model adapter (in other words specify connection) - override `.adapter` method:

```crystal
class User < Jennifer::Model::Base
  # ...

  def self.adapter
    SEPARATE_ADAPTER
  end
end
```

In this case `SEPARATE_ADAPTER` is used for **both** read and write operations. If you need to connect to the specified database only for read or write operation you can override `.read_adapter` or `.write_adapter`.

It is possible to define associations between models that are in different databases but be careful with `JOIN`s - obviously it isn't possible. But you can preload them (as it does separate requests per association).

## Migration

To specify using which adapter you are going to execute a database migration you should define `#adapter` method:

```crystal
class SomeMigration < Jennifer::Migration::Base
  def adapter
    SEPARATE_ADAPTER
  end

  def up
    # ...
  end

  def down
    # ...
  end
end
```

As a result all operations in `#up` and `#down` will be executed using `SEPARATE_ADAPTER`.

> Migration instance can operate only in a scope of one adapter. If you want to apply changes to tables in multiple databases - use multiple migrations.

If you need to create/drop a database for extra connection you have to define own Sam task (or handle it somehow). You can redefine `db:create` and `db:drop` task as follows:

```crystal
Sam.namespace "db" do
  task "create" do
    Jennifer::Migration::Runner.create
    Jennifer::Migration::Runner.create(SEPARATE_ADAPTER)
  end

  task "drop" do
    Jennifer::Migration::Runner.drop
    Jennifer::Migration::Runner.drop(SEPARATE_ADAPTER)
  end
end
```

Now when you execute those commands you will affect both connections.
