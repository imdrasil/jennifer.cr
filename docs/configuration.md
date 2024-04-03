# Configuration

Put

```crystal
require "jennifer"
require "jennifer/adapter/mysql" # for mysql
require "jennifer/adapter/postgres" # for postgres
```

> Be attentive - adapter should be required **after** Jennifer. From `0.5.0` several adapters could be required at the same time.

[SQLite3](https://github.com/imdrasil/jennifer_sqlite3_adapter) adapter is in a separate shard.

This should be done before you load your application configurations (or at least models). Now configuration could be loaded from yaml file:

```crystal
Jennifer::Config.read("./spec/fixtures/database.yml", :development)
```

Second argument presents environment and just use it as namespace key grepping values from yml.

```yaml
defaults : &defaults
  host: localhost
  adapter: postgres
  user: developer
  password: 1qazxsw2
  migration_files_path: ./any/path/migrations # ./db/migrations by default
  pool_size: 5

development:
  db: jennifer_develop
  <<: *defaults

test:
  db: jennifer_test
  <<: *defaults
```

You cam also use `.ecr` extension to leverage environmet variables in your configuration file. To do this use:

```crystal
config_file = YAML.parse(ECR.render("config/database.yml.ecr"))
Jennifer::Config.configure do |conf|
  conf.from_yaml(config_file[ENV["APP_ENV"]])
end
```

All configurations also can be set using DSL:

```crystal
Jennifer::Config.configure do |conf|
  conf.host = "localhost"
  conf.user = "root"
  conf.password = ""
  conf.adapter = "mysql"
  conf.db = "crystal"
  conf.migration_files_path = "./any/path/migrations"
  conf.pool_size = (ENV["DB_CONNECTION_POOL"]? || 5).to_i
end
```

If your configurations aren't stored on the top level - you can manipulate which document subpart will be used to parse parameters:

```crystal
Jennifer::Config.read("./spec/fixtures/database.yml", &.["database"]["development"])
```

Also some configuration can be parsed directly from a URI:

```crystal
db_uri = "mysql://root@somehost/some_database?max_pool_size=111&initial_pool_size=222&max_idle_pool_size=333&retry_attempts=444&checkout_timeout=555&retry_delay=666"
Jennifer::Config.from_uri(db)
```

## Supported configuration options

* `host` - database host; default: `"localhost"`
* `port` - database port; default: `-1` (`-1` value makes adapter to skip port in building connection URL, specify required port number)
* `schema` - PostgreSQL database schema name; default: `"public"`
* `user` - database user name used to connect to the database
* `password` - database user password used to connect to the database (if not specified - connection URL will specify only user name)
* `db` - database name
* `adapter` - adapter name to be used to connect to the database (e.g. `"postgres"`)
* `pool_size` - count of simultaneously alive database connection; default: `1`
* `retry_attempts` - count of attempts to connect to the database before raising an exception; default: `1`
* `retry_delay` - amount of seconds to wait between connection retries; default: `1.0`
* `auth_methods` - comma separated list of auth methods; optional; default: `""`; available methods: `cleartext,md5,scram-sha-256,scram-sha-256-plus`; `crystal-pg` uses `scram-sha-256-plus,scram-sha-256,md5` if not provided
* `sslmode` - determines whether or with what priority a secure SSL TCP/IP connection will be negotiated with the server; optional; default `""`; There are six modes: `disable`, `allow`, `prefer`, `require`, `verify-ca`, `verify-full`; `crystal-pg` uses `prefer` if not provided
* `sslcert` - file path to client SSL certificate; optional; default: `""`
* `sslkey` - file path to secret key used for the client certificate; optional; default: `""`
* `sslrootcert` - file path to SSL certificate authority (CA) certificate(s) which is used to verify the server's certificate; optional; default: `""`
* `checkout_timeout` - amount of seconds to be wait for connection; default: `5.0`
* `local_time_zone_name` - local time zone name; automatically taken from `Time::Location.local.name`
* `skip_dumping_schema_sql` - skip dumping database structure if set to `true`; default: `false`
* `allow_outdated_pending_migration` - allows outdated pending migrations (which version is below the latest run migration) to be invoked without exception; default: `false`
* `command_shell` - the name of system command interface to be used for some operations that require system calls; default: `"bash"`; `"docker"` value makes commands to be invoked inside of specified docker container
* `docker_container` - container name with database instance (is used when `command_shell` set to `"docker"`); default: `""`
* `docker_source_location` - default source location prefix for the executables inside of docker container (is used when `command_shell` set to `"docker"`); default: `""`
* `command_shell_sudo` - marks whether system commands should be invoked with `sudo`; default: `false`
* `migration_failure_handler_method` - strategy used on migration file failure; default: `"none"`; supported:
  * `"none"` - do nothing
  * `"reverse_direction"` - invokes an opposite method to migration direction (`#down` for an up-migration)
  * `"callback"` - invokes `#after_up_failure` on a failed up-migration and `#after_down_failure` on a failed down-migration
* `migration_files_path` - path to the location with migration files; default: `"./db/migrations"`
* `verbose_migrations` - outputs basic information about invoked migrations; default: `true`
* `model_files_path` - path to the models location; is used by model and migration generators; default: `"./src/models"`
* `structure_folder` - path to the database structure file location; if set to empty string - parent folder of `migration_files_path` is used; default: `""`
* `max_bind_vars_count` - maximum allowed count of bind variables; if nothing specified - used adapter's default value; default: `nil`
* `time_zone_aware_attributes` - whether Jennifer should convert time objects to UTC and back to application time zone when store/load them from a database; default: `true`

## Logging

Jennifer uses [standard](https://crystal-lang.org/api/latest/Log.html) Crystal logging mechanism so you could specify your own logger:

```crystal
require "jennifer/adapter/db_colorized_formatter"

Log.setup "db", :debug, Log::IOBackend.new(formatter: Jennifer::Adapter::DBColorizedFormatter)

# or colorless

Log.setup "db", :debug, Log::IOBackend.new(formatter: Jennifer::Adapter::DBFormatter)
```

More about logging could be found [in the crystal doc](https://crystal-lang.org/api/latest/Log.html).

## Command Shell

Some database related operations need to be performed by invoking bash command (like creating or dropping database). By default bash shell is used for such purposes under user invoking this operation, but this may be specified.

To specify another command shell set `command_shell` configuration to another registered one. One more onboard command shell is `"docker"` but you mau also define your own. To do this you should inherit from `Jennifer::Adapter::ICommandShell` abstract class and register it:

```crystal
class MySimpleDocker < Jennifer::Adapter::ICommandShell
  def execute(command)
    command_string = String.build do |io|
      io << "sudo " if config.command_shell_sudo
      io << "docker exec -i "
      io << config.docker_container
      io << " "
      io << command.executable
      io << " "
      io << OPTIONS_PLACEHOLDER
    end
    invoke(command_string, command.options)
  end
end

Jennifer::Adapter::DBCommandInterface.register_shell("my_docker", MySimpleDocker)
```
